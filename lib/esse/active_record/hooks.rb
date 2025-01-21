# frozen_string_literal: true

module Esse
  module ActiveRecord
    module Hooks
      STORE_STATE_KEY = :esse_active_record_hooks

      include Esse::Hooks[store_key: STORE_STATE_KEY]
    end
  end
end
