# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnCreate < Callback
      def call(model)
        record = block_result || model
        document = repo.serialize(record)
        repo.index.index(document, **options) if document
        true
      end
    end

    register_callback(:index, :create, IndexingOnCreate)
  end
end
