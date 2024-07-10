# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnUpdate < Callback
      def call(model)
        record = block_result || model

        document = repo.serialize(record)
        return true unless document

        repo.index.index(document, **options)
        return true unless document.routing

        prev_record = model.class.new(model.attributes.merge(model.previous_changes.transform_values(&:first))).tap(&:readonly!)
        prev_document = repo.serialize(prev_record)

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
    end

    register_callback(:indexing, :update, IndexingOnUpdate)
  end
end
