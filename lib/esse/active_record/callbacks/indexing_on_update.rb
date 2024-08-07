# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnUpdate < Callback
      def call(model)
        record = block_result || model

        document = repo.serialize(record)
        return true unless document

        update_document(document)
        return true unless document.routing

        prev_record = model.class.new
        model.attributes.merge(model.previous_changes.transform_values(&:first)).each do |key, value|
          prev_record[key] = value
        end
        prev_document = repo.serialize(prev_record.tap(&:readonly!))

        return true unless prev_document
        return true if [prev_document.id, prev_document.routing].include?(nil)
        return true if prev_document.routing == document.routing
        return true if prev_document.id != document.id

        begin
          repo.index.delete(prev_document, **options)
        rescue Esse::Transport::NotFoundError
        end

        true
      end

      protected

      def update_document(document)
        return if document.ignore_on_index?

        if @with == :update || (@with.nil? && repo.lazy_document_attributes.any?)
          begin
            repo.index.update(document, **options)
          rescue Esse::Transport::NotFoundError
            repo.index.index(document, **options)
          end
        else
          repo.index.index(document, **options)
        end
      end
    end

    register_callback(:indexing, :update, IndexingOnUpdate)
  end
end
