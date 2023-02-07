require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Collection, '.scope' do
  describe '.scope definition' do
    it 'defines a scope' do
      collection = Class.new(described_class)
      expect {
        collection.scope(:foo, -> { Animal.all })
      }.to change { collection.scopes.keys }.from([]).to([:foo])
    end

    it 'defines a scope with a block' do
      collection = Class.new(described_class)
      expect {
        collection.scope(:foo) { Animal.all }
      }.to change { collection.scopes.keys }.from([]).to([:foo])
    end

    it 'raises an error when scope is not defined' do
      collection = Class.new(described_class)
      expect {
        collection.scope(:foo)
      }.to raise_error(ArgumentError)
    end

    it 'raises an error when scope is already defined' do
      collection = Class.new(described_class)
      collection.scope(:foo) { Animal.all }
      expect {
        collection.scope(:foo) { Animal.all }
      }.to raise_error(ArgumentError)
    end

    it 'allows overriding a scope by passing override: true as argument' do
      collection = Class.new(described_class)
      collection.scope(:foo) { Animal.all }
      expect {
        collection.scope(:foo, override: true) { Animal.all }
      }.not_to raise_error
    end

    it 'does not modify the parent scopes when inherited' do
      collection = Class.new(described_class)
      collection.scope(:foo) { Animal.all }
      expect {
        Class.new(collection).scope(:bar) { Animal.all }
      }.not_to change { collection.scopes }
    end

    it 'inherits scopes from parent' do
      collection = Class.new(described_class)
      collection.scope(:foo) { Animal.all }
      expect(Class.new(collection).scopes).to eq(collection.scopes)
    end
  end

  describe '#each using scopes' do
    let(:collection_class) do
      klass = Class.new(described_class)
      klass.base_scope = -> { Dog }
      klass
    end

    after do
      Dog.destroy_all
    end

    context 'when filtering by a non-existent scope' do
      it 'raises an error' do
        instance = collection_class.new(some_missing_scope: 'test')
        expect {
          instance.each { |rows| }
        }.to raise_error(ArgumentError, "Unknown scope `some_missing_scope'")
      end

      it 'applies the scope block with arity equals to zero to the dataset' do
        collection_class.scope(:foo, override: true) { where(name: 'foo') }

        instance = collection_class.new(foo: true)
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        expect { |b| instance.each(&b) }.to yield_successive_args([[dog_foo], { foo: true }])
      end

      it 'applies the scope lambda with arity equals to the dataset' do
        collection_class.scope(:foo, -> { where(name: 'foo') }, override: true)

        instance = collection_class.new(foo: true)
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        expect { |b| instance.each(&b) }.to yield_successive_args([[dog_foo], { foo: true }])
      end

      it 'applies the scope block with arity greater than zero to the dataset' do
        collection_class.scope(:my_name, override: true) { |name| where(name: name) }

        instance = collection_class.new(my_name: 'foo')
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        expect { |b| instance.each(&b) }.to yield_successive_args([[dog_foo], { my_name: 'foo' }])
      end

      it 'applies the scope lambda with arity greater than zero to the dataset' do
        collection_class.scope(:my_name, ->(name) { where(name: name) }, override: true)

        instance = collection_class.new(my_name: 'foo')
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        expect { |b| instance.each(&b) }.to yield_successive_args([[dog_foo], { my_name: 'foo' }])
      end
    end
  end
end
