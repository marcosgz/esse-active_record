# frozen_string_literal: true

module Esse::ActiveRecord
  module Callbacks
    class IndexingOnUpdate < Callback
    end

    register_callback(:index, :update, IndexingOnUpdate)
  end
end
