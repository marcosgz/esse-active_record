# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class UpdateLazyAttribute < Callback
      attr_reader :attribute_name

      def initialize(attribute_name:, **kwargs, &block)
        @attribute_name = attribute_name
        super(**kwargs, &block)
      end

      def call(model)
        related_ids = Array(block_result || model.id)
        return true if related_ids.empty?

        repo.update_documents_attribute(attribute_name, *related_ids, **options)

        true
      end
    end

    register_callback(:update_lazy_attribute, :create, UpdateLazyAttribute)
    register_callback(:update_lazy_attribute, :update, UpdateLazyAttribute)
    register_callback(:update_lazy_attribute, :destroy, UpdateLazyAttribute)
  end
end
