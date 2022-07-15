module Esse
  module ActiveRecord
    class Collection
      include Enumerable

      class_attribute :scope, :batch_size, :scope_prefix

      def initialize(**params)
        @params = params
      end

      def self.inspect
        return super unless self < Esse::ActiveRecord::Collection
        return super unless scope

        format('#<Esse::ActiveRecord::Collection__%s>', model)
      end

      def self.model
        reise(NotImplementedError, "No model defined for #{self}") unless scope

        scope.call.all.model
      end

      def each
        dataset.find_in_batches(batch_size: batch_size) do |rows|
          yield(rows, **@params)
        end
      end

      def dataset(**kwargs)
        query = self.class.scope&.call || raise(NotImplementedError, "No scope defined for #{self.class}")
        query = query.except(:order, :limit, :offset)
        @params.merge(kwargs).each do |key, value|
          if query.model.columns_hash.key?(key.to_s)
            query = query.where(key => value)
          end
        end

        query
      end

      def inspect
        return super unless self.class < Esse::ActiveRecord::Collection
        return super unless self.class.scope

        vars = instance_variables.map do |n|
          "#{n}=#{instance_variable_get(n).inspect}"
        end
        format('#<Esse::ActiveRecord::Collection__%s:0x%x %s>', self.class.model, object_id, vars.join(', '))
      end

      protected

      def prefixed_scope(name)
        [scope_prefix.presence, name].compact.join('_')
      end

      def scope_prefix
        return if self.class.scope_prefix == false

        self.class.scope_prefix || 'esse'
      end

      def batch_size
        self.class.batch_size || 1000
      end
    end
  end
end
