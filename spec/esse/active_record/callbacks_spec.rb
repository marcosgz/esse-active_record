require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Callbacks do
  before do
    @__callbacks = described_class.instance_variable_get(:@callbacks)
    described_class.instance_variable_set(:@callbacks, nil)
  end

  after do
    described_class.instance_variable_set(:@callbacks, @__callbacks) # rubocop:disable RSpec/InstanceVariable
  end

  describe '.to_h' do
    it 'returns an empty hash' do
      expect(described_class.to_h).to eq({})
    end

    it 'returns a frozen hash' do
      expect(described_class.to_h).to be_frozen
    end
  end

  describe '.register_callback' do
    it 'registers a callback' do
      expect {
        described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      }.to change { described_class.to_h.size }.by(1)
      expect(described_class.to_h).to be_frozen
    end

    it 'raises an error if the callback is already registered' do
      described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      expect {
        described_class.register_callback(:external, :create, Class.new(Esse::ActiveRecord::Callback))
      }.to raise_error(ArgumentError, 'callback external for create operation already registered')
      expect(described_class.to_h).to be_frozen
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

  describe '.fetch!' do
    it 'raises an error if the callback is not registered' do
      expect {
        described_class.fetch!(:external, :create)
      }.to raise_error(ArgumentError, 'callback external for create operation not registered')
    end

    it 'returns the callback class' do
      klass = Class.new(Esse::ActiveRecord::Callback)
      described_class.register_callback(:external, :create, klass)
      expect(described_class.fetch!(:external, :create)).to eq([:external_on_create, klass])
    end
  end
end

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
