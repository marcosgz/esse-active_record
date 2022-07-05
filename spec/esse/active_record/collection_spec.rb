require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Collection do
  describe '#initialize' do
    it 'creates a new collection' do
      collection = described_class.new
      expect(collection).to be_a(described_class)
    end
  end

  describe '.scope' do
    it 'does not override the parent scope' do
      described_class.scope = :foo
      expect(described_class.scope).to eq(:foo)
      child = Class.new(described_class)
      expect(child.scope).to eq(:foo)
      child.scope = :bar
      expect(child.scope).to eq(:bar)
      expect(described_class.scope).to eq(:foo)
      described_class.scope = nil
    end
  end

  describe '#each' do
    it 'raises NotImplementedError when scope is not defined on the collection class' do
      expect {
        collection = described_class.new
        collection.each
      }.to raise_error(NotImplementedError)
    end

    it 'returns an Enumerator with a relation instance' do
      collection = Class.new(described_class)
      collection.scope = -> { Animal.all }
      expect { |b| collection.new.each(&b) }.not_to yield_control
    end

    it 'returns an Enumerator with a model class' do
      collection = Class.new(described_class)
      collection.scope = -> { Animal }
      expect { |b| collection.new.each(&b) }.not_to yield_control
    end

    context 'with filter parameters' do
      let(:dog_class) do
        Class.new(Animal) do
          def self.name
            'Dog'
          end
        end
      end

      let(:collection_class) do
        klass = Class.new(described_class)
        klass.scope = -> { Dog }
        klass
      end

      before do
        Object.const_set(:Dog, dog_class)
      end

      after do
        Dog.destroy_all
        Object.send(:remove_const, :Dog)
      end

      it 'filteres by existing attributes' do
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        collection = collection_class.new(name: 'foo')
        expect(collection.to_a.size).to eq(1)

        expect { |b| collection_class.new(name: 'foo').each(&b) }.to yield_successive_args([[dog_foo], {name: 'foo'}])
      end
    end
  end

  describe '#dataset' do
    it 'returns an ActiveRecord::Relation' do
      collection = Class.new(described_class)
      collection.scope = -> { Animal.all }
      expect(collection.new.dataset).to be_a(::ActiveRecord::Relation)
    end

    it 'returns an ActiveRecord::Relation with a scope' do
      collection = Class.new(described_class)
      collection.scope = -> { Animal.where(name: 'foo') }

      expect(collection.new.dataset).to be_a(::ActiveRecord::Relation)
      expect(collection.new.dataset.to_sql).to eq(Animal.where(name: 'foo').to_sql)
    end
  end
end
