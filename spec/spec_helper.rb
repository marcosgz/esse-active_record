# frozen_string_literal: true

require 'bundler/setup'
require 'dotenv/load'
require 'esse/active_record'
require 'esse/rspec'

require 'support/config_helpers'
require 'support/sharding_hook'
require 'support/webmock'
require 'support/models'
require 'pry'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.include ConfigHelpers
end
