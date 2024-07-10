# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnCreate < Callback
    end

    register_callback(:index, :create, IndexingOnCreate)
  end
end
