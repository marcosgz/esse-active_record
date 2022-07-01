# frozen_string_literal: true

require 'active_record'

module Esse
  module Plugins
    module ActiveRecord
      module RepositoryClassMethods
        # @param [String, Symbol] type_name The document type name
        # @param [Class] model_class The ActiveRecord Relation or model class
        # @param [Hash] options The options
        # @option options [Symbol] :batch_size The batch size for the collection
        def collection(*args, **kwargs, &block)
          type_name, model_class = normalize_type_and_model(*args)
          unless model_or_relation?(model_class)
            return super(*args, **kwargs, &block)
          end

          repo = Class.new(Esse::ActiveRecord::Collection)
          repo.scope = -> { model_class }
          repo.batch_size = kwargs[:batch_size]
          repo.scope_prefix = kwargs[:scope_prefix]

          super(type_name, repo)
        end

        private

        def normalize_type_and_model(type, model = nil, *)
          if model_or_relation?(type)
            model = type
            type = model.model_name.param_key
          end
          [type, model]
        end

        def model_or_relation?(klass)
          return false unless klass.is_a?(Class)
          return true if klass < ::ActiveRecord::Base
          return true if klass.is_a?(::ActiveRecord::Relation)

          false
        end
      end
    end
  end
end
