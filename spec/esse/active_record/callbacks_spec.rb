require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Callbacks do
  before do
    described_class.instance_variable_set(:@callbacks, nil)
  end

  describe '.to_h' do
    it 'returns an empty hash' do
      expect(described_class.to_h).to eq({})
    end
  end

  describe '.register_callback' do
    it 'registers a callback' do
      expect {
        described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      }.to change { described_class.to_h.size }.by(1)
    end

    it 'raises an error if the callback is already registered' do
      described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      expect {
        described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      }.to raise_error(ArgumentError, 'callback external for create operation already registered')
    end
  end

  describe '.registered?' do
    it 'returns false if the callback is not registered' do
      expect(described_class.registered?(:external, :create)).to eq(false)
    end

    it 'returns true if the callback is registered' do
      described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      expect(described_class.registered?(:external, :create)).to eq(true)
    end
  end
end

RSpec.describe Esse::ActiveRecord::Callback do
  let(:callback_class) do
    Class.new(described_class)
  end

  it 'raises an error if #call is not implemented' do
    expect {
      callback_class.new.call
    }.to raise_error(NotImplementedError, 'You must implement #call method')
  end

  it 'has options' do
    callback = callback_class.new(foo: 'bar')
    expect(callback.options).to eq(foo: 'bar')
  end

  it 'has a block' do
    callback = callback_class.new { 'foo' }
    expect(callback.block.call).to eq('foo')
  end
end
