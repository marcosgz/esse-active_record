# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnCreate < Callback
      def call(model)
        record = block_result || model
        document = repo.serialize(record)
        repo.index.index(document, **options) if document && !document.ignore_on_index?
        true
      end
    end

    register_callback(:indexing, :create, IndexingOnCreate)
  end
end
