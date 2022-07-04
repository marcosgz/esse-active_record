# frozen_string_literal: true

require 'active_record'

module Esse
  module Plugins
    module ActiveRecord
      module RepositoryClassMethods
        # @param [Class] model_class The ActiveRecord Relation or model class
        # @param [Hash] options The options
        # @option options [Symbol] :batch_size The batch size for the collection
        def collection(*args, **kwargs, &block)
          unless model_or_relation?(args.first)
            return super(*args, **kwargs, &block)
          end
          model_class = args.shift
          type = model_class.model_name.param_key

          repo = Class.new(Esse::ActiveRecord::Collection)
          repo.scope = -> { model_class }
          repo.batch_size = kwargs[:batch_size]
          repo.scope_prefix = kwargs[:scope_prefix]

          super(repo, *args, **kwargs, &block)
        end

        private

        def model_or_relation?(klass)
          return true if klass.is_a?(Class) && klass < ::ActiveRecord::Base
          return true if klass.is_a?(::ActiveRecord::Relation)

          false
        end
      end
    end
  end
end
