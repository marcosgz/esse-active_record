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
        end

        def scope(name, proc = nil, override: false, &block)
          proc = proc&.to_proc || block
          raise ArgumentError, 'proc or block required' unless proc
          raise ArgumentError, "scope `#{name}' already defined" if !override && scopes.key?(name.to_sym)

          scopes[name.to_sym] = proc
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
        dataset.find_in_batches(**batch_options) do |rows|
          yield(rows, **params)
        end
      end

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
