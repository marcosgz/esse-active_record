require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Model do
  let(:model) do
    Class.new(State) do
      include Esse::ActiveRecord::Model
    end
  end

  it 'responds to .index_callback' do
    expect(model).to respond_to(:index_callback)
  end

  it 'responds to .esse_callback' do
    expect(model).to respond_to(:esse_callback)
  end
end
