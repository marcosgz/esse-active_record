require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Collection, '.batch_context' do
  describe '.batch_context definition' do
    it 'defines a context' do
      collection = Class.new(described_class)
      expect {
        collection.batch_context(:foo, ->(rows, **) { %w[bar] })
      }.to change { collection.batch_contexts.keys }.from([]).to([:foo])
    end

    it 'defines a context with a block' do
      collection = Class.new(described_class)
      expect {
        collection.batch_context(:foo) { |rows, **| %w[bar] }
      }.to change { collection.batch_contexts.keys }.from([]).to([:foo])
    end

    it 'raises an error when neither a block nor a proc is passed' do
      collection = Class.new(described_class)
      expect {
        collection.batch_context(:foo)
      }.to raise_error(ArgumentError)
    end

    it 'raises an error when context is already defined' do
      collection = Class.new(described_class)
      collection.batch_context(:foo) { |*| :bar }
      expect {
        collection.batch_context(:foo) { |*| :bar }
      }.to raise_error(ArgumentError)
    end

    it 'allows overriding a context by passing override: true as argument' do
      collection = Class.new(described_class)
      collection.batch_context(:foo) { |*| :foo }
      expect {
        collection.batch_context(:foo, override: true) { |*| :bar }
      }.not_to raise_error
    end

    it 'does not modify the parent batch_contexts when inherited' do
      collection = Class.new(described_class)
      collection.batch_context(:foo) { |*| :foo }
      expect {
        Class.new(collection).batch_context(:bar) { |*| :bar }
      }.not_to change { collection.batch_contexts }
    end

    it 'inherits batch_contexts from parent' do
      collection = Class.new(described_class)
      collection.batch_context(:foo) { |*| :foo }
      expect(Class.new(collection).batch_contexts).to eq(collection.batch_contexts)
    end
  end

  describe '#each using batch_contexts' do
    let(:collection_class) do
      klass = Class.new(described_class)
      klass.base_scope = -> { County }
      klass
    end

    after do
      [County, State].each(&:delete_all)
    end

    it 'does not apply any context when it is not defined' do
      lake_county = County.create!(name: 'Lake')
      instance = collection_class.new
      expect { |b| instance.each(&b) }.to yield_successive_args([[lake_county], {}])
    end

    it 'only applies the params as context when no batch context is defined' do
      il_state = State.create!(name: 'Illinois', abbr_name: 'IL')
      cook_county = County.create!(name: 'Cook', state: il_state)
      instance = collection_class.new(state_id: il_state.id)
      expect { |b| instance.each(&b) }.to yield_successive_args([[cook_county], { state_id: il_state.id }])
    end

    it 'appends the batch context to the list of parames yielded on each batch' do
      collection_class.batch_context(:county_state) { |rows, **| rows.each_with_object({}) { |r, m| m[r.id] = r.state&.name } }
      il_state = State.create!(name: 'Illinois', abbr_name: 'IL')
      lake_county = County.create!(name: 'Lake', state: il_state)
      instance = collection_class.new
      expect { |b| instance.each(&b) }.to yield_successive_args([[lake_county], { county_state: { lake_county.id => il_state.name } }])
    end
  end
end
