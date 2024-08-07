module Esse
  module ActiveRecord
    class Collection
      include Enumerable

      # The model class or the relation to be used as the scope
      # @return [Proc]
      class_attribute :base_scope

      # The number of records to be returned in each batch
      # @return [Integer]
      class_attribute :batch_size

      # Hash with the custom scopes defined on the model
      # @return [Hash]
      class_attribute :scopes
      self.scopes = {}

      # The hash with the contexts as key and the transformer proc as value
      # @return [Hash]
      class_attribute :batch_contexts
      self.batch_contexts = {}

      # Connects to a database or role (ex writing, reading, or another custom role) for the collection query
      # @param [Symbol] role The role to connect to
      # @param [Symbol] shard The shard to connect to
      class_attribute :connect_with
      self.connect_with = nil

      class << self
        def inspect
          return super unless self < Esse::ActiveRecord::Collection
          return super unless base_scope

          format('#<Esse::ActiveRecord::Collection__%s>', model)
        end

        def model
          raise(NotImplementedError, "No model defined for #{self}") unless base_scope

          base_scope.call.all.model
        end

        def inherited(subclass)
          super

          subclass.scopes = scopes.dup
          subclass.batch_contexts = batch_contexts.dup
          subclass.connect_with = connect_with&.dup
        end

        def scope(name, proc = nil, override: false, &block)
          proc = proc&.to_proc || block
          raise ArgumentError, 'proc or block required' unless proc
          raise ArgumentError, "scope `#{name}' already defined" if !override && scopes.key?(name.to_sym)

          scopes[name.to_sym] = proc
        end

        def batch_context(name, proc = nil, override: false, &block)
          proc = proc&.to_proc || block
          raise ArgumentError, 'proc or block required' unless proc
          raise ArgumentError, "batch_context `#{name}' already defined" if !override && batch_contexts.key?(name.to_sym)

          batch_contexts[name.to_sym] = proc
        end

        def connected_to(**kwargs)
          self.connect_with = kwargs
        end
      end

      attr_reader :start, :finish, :batch_size, :params

      # @param [Integer] start Specifies the primary key value to start from, inclusive of the value.
      # @param [Integer] finish  Specifies the primary key value to end at, inclusive of the value.
      # @param [Integer] batch_size The number of records to be returned in each batch. Defaults to 1000.
      # @param [Hash] params The query criteria
      # @return [Esse::ActiveRecord::Collection]
      def initialize(start: nil, finish: nil, batch_size: nil, **params)
        @start = start
        @finish = finish
        @batch_size = batch_size || self.class.batch_size || 1000
        @params = params
      end

      def each
        with_connection do
          dataset.find_in_batches(**batch_options) do |rows|
            kwargs = params.dup
            self.class.batch_contexts.each do |name, proc|
              kwargs[name] = proc.call(rows, **params)
            end
            yield(rows, **kwargs)
          end
        end
      end

      def each_batch_ids
        with_connection do
          dataset.select(:id).except(:includes, :preload, :eager_load).find_in_batches(**batch_options) do |rows|
            yield(rows.map(&:id))
          end
        end
      end

      def count
        with_connection do
          dataset.except(:includes, :preload, :eager_load, :group, :order, :limit, :offset).count
        end
      end
      alias_method :size, :count

      def dataset(**kwargs)
        query = self.class.base_scope&.call || raise(NotImplementedError, "No scope defined for #{self.class}")
        query = query.except(:order, :limit, :offset)
        params.merge(kwargs).each do |key, value|
          if self.class.scopes.key?(key)
            scope_proc = self.class.scopes[key]
            query = if scope_proc.arity == 0
              query.instance_exec(&scope_proc)
            else
              query.instance_exec(value, &scope_proc)
            end
          elsif query.model.columns_hash.key?(key.to_s)
            query = query.where(key => value)
          else
            raise ArgumentError, "Unknown scope `#{key}'"
          end
        end

        query
      end

      def inspect
        return super unless self.class < Esse::ActiveRecord::Collection
        return super unless self.class.base_scope

        vars = instance_variables.map do |n|
          "#{n}=#{instance_variable_get(n).inspect}"
        end
        format('#<Esse::ActiveRecord::Collection__%s:0x%x %s>', self.class.model, object_id, vars.join(', '))
      end

      protected

      def with_connection
        if self.class.connect_with&.any?
          ::ActiveRecord::Base.connected_to(**self.class.connect_with) do
            yield
          end
        else
          yield
        end
      end

      def batch_options
        {
          batch_size: batch_size
        }.tap do |hash|
          hash[:start] = start if start
          hash[:finish] = finish if finish
        end
      end
    end
  end
end
