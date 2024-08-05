# frozen_string_literal: true

module ShardingHook
  extend ActiveSupport::Concern

  included do
    around do |example|
      if example.metadata[:sharding] &&
          !ActiveRecord::Base.respond_to?(:connected_to)
        skip 'ActiveRecord::Base.connected_to is not available in this version of Rails'
        return
      end

      example.run
    end
  end
end

RSpec.configure do |config|
  config.include ShardingHook
end
