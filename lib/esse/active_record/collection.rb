module Esse
  module ActiveRecord
    class Collection
      include Enumerable

      class_attribute :scope, :batch_size, :scope_prefix

      def initialize(**params)
        @params = params
      end

      def each
        scope.find_in_batches(batch_size: batch_size) do |rows|
          yield(rows, **@params)
        end
      end

      protected

      def scope
        query = self.class.scope&.call || raise(NotImplementedError, "No scope defined for #{self.class}")
        query = query.except(:order, :limit, :offset)
        @params.each do |key, value|
          if query.model.columns_hash.key?(key.to_s)
            query = query.where(key => value)
          end
        end

        query
      end

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
