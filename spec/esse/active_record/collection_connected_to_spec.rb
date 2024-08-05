require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Collection, '.connected_to' do
  let(:collection_class) { Class.new(described_class) }

  describe '.connected_to' do
    it 'sets the connect_with' do
      collection_class.connected_to(role: :reading, shard: :default)
      expect(collection_class.connect_with).to eq(role: :reading, shard: :default)
    end
  end

  describe '#each using custom connection', sharding: true do
    let(:collection_class) do
      klass = Class.new(described_class)
      klass.base_scope = -> { State }
      klass.connected_to(role: :reading)
      klass
    end

    it 'uses the custom connection' do
      expect(ActiveRecord::Base).to receive(:connected_to).with(role: :reading).and_call_original
      il_state = State.create!(name: 'Illinois', abbr_name: 'IL')

      instance = collection_class.new
      expect { |b| instance.each(&b) }.to yield_successive_args([il_state])
      il_state.destroy
    end
  end

  describe '#each_batch_ids using custom connection', sharding: true do
    let(:collection_class) do
      klass = Class.new(described_class)
      klass.base_scope = -> { State }
      klass.connected_to(role: :reading)
      klass
    end

    it 'uses the custom connection' do
      expect(ActiveRecord::Base).to receive(:connected_to).with(role: :reading).and_call_original
      il_state = State.create!(name: 'Illinois', abbr_name: 'IL')

      instance = collection_class.new
      expect { |b| instance.each_batch_ids(&b) }.to yield_successive_args([il_state.id])
      il_state.destroy
    end
  end

  describe '#count using custom connection', sharding: true do
    let(:collection_class) do
      klass = Class.new(described_class)
      klass.base_scope = -> { State }
      klass.connected_to(role: :reading)
      klass
    end

    it 'uses the custom connection' do
      expect(ActiveRecord::Base).to receive(:connected_to).with(role: :reading).and_call_original
      il_state = State.create!(name: 'Illinois', abbr_name: 'IL')

      instance = collection_class.new
      expect(instance.count).to eq(1)
      il_state.destroy
    end
  end
end
