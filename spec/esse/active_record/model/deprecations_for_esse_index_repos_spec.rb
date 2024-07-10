# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Model, '.esse_index_repos' do
  specify do
    Gem::Deprecate.skip_during do
      model_class = Class.new(State) do
        include Esse::ActiveRecord::Model
        index_callback 'states_index'
      end
      expect(model_class.esse_index_repos.keys).to include('states_index')
    end
  end
end
