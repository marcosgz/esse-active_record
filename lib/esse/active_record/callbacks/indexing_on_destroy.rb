# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnDestroy < Callback
      def call(model)
        record = block_result || model
        document = repo.serialize(record)
        repo.index.delete(document, **options) if document && !document.ignore_on_delete?
        true
      rescue Esse::Transport::NotFoundError
        true
      end
    end

    register_callback(:indexing, :destroy, IndexingOnDestroy)
  end
end
