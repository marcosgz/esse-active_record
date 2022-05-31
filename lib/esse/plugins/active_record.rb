# frozen_string_literal: true

require 'active_record'

module Esse
  module Plugins
    module ActiveRecord
      module ClassMethods
        # @param [String, Symbol] type_name The document type name
        # @param [Class] model_class The ActiveRecord Relation or model class
        # @param [Hash] options The options
        # @option options [Symbol] :batch_size The batch size for the collection
        def define_type(*args, **kwargs, &block)
          type_name, ar_class = args
          if type_name.is_a?(Class) && (type_name < ::ActiveRecord::Base || type_name.is_a?(::ActiveRecord::Relation))
            ar_class = type_name
            type_name = ar_class.model_name.param_key
          end
          if !ar_class.is_a?(Class) && !(ar_class < ::ActiveRecord::Base) && !ar_class.is_a?(::ActiveRecord::Relation)
            return super(*args, &block)
          end

          type_class = super(type_name, &block)

          collection = Class.new(Esse::ActiveRecord::Collection)
          collection.scope = -> { ar_class }
          collection.batch_size = kwargs[:batch_size]
          collection.scope_prefix = kwargs[:scope_prefix]
          type_class.collection(collection)
        end
      end
    end
  end
end
