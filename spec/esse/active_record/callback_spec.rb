require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Callback do
  let(:callback_class) do
    Class.new(described_class)
  end
  let(:repo) { double }

  it 'raises an error if #call is not implemented' do
    expect {
      callback_class.new(repo: repo).call(nil)
    }.to raise_error(NotImplementedError, 'You must implement #call method')
  end

  it 'has options' do
    callback = callback_class.new(repo: repo, foo: 'bar')
    expect(callback.options).to eq(foo: 'bar')
  end

  it 'has a block result' do
    callback = callback_class.new(repo: repo, block_result: 'result')
    expect(callback.block_result).to eq('result')
  end
end
