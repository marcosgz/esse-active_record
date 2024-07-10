# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnDestroy < Callback
    end

    register_callback(:index, :destroy, IndexingOnDestroy)
  end
end
