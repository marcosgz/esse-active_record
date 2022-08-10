require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Collection do
  describe '#initialize' do
    it 'creates a new collection' do
      collection = described_class.new
      expect(collection).to be_a(described_class)
    end
  end

  describe '.base_scope' do
    it 'does not override the parent scope' do
      described_class.base_scope = :foo
      expect(described_class.base_scope).to eq(:foo)
      child = Class.new(described_class)
      expect(child.base_scope).to eq(:foo)
      child.base_scope = :bar
      expect(child.base_scope).to eq(:bar)
      expect(described_class.base_scope).to eq(:foo)
      described_class.base_scope = nil
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
      collection.base_scope = -> { Animal.all }
      expect { |b| collection.new.each(&b) }.not_to yield_control
    end

    it 'returns an Enumerator with a model class' do
      collection = Class.new(described_class)
      collection.base_scope = -> { Animal }
      expect { |b| collection.new.each(&b) }.not_to yield_control
    end

    context 'with start and batch_size' do
      let(:collection_class) do
        klass = Class.new(described_class)
        klass.base_scope = -> { Dog }
        klass
      end

      let!(:dogs) do
        Array.new(3) { |i| Dog.create!(name: "Dog #{i.next}") }
      end

      after do
        Dog.destroy_all
      end

      it 'stream data in batches according to the :batch_size option' do
        instance = collection_class.new(batch_size: 1)

        expect { |b| instance.each(&b) }.to yield_successive_args([dogs[0..0], {}], [dogs[1..1], {}], [dogs[2..2], {}])
      end

      it 'stream data in batches according to the :batch_size option and :start option' do
        instance = collection_class.new(batch_size: 1, start: dogs[1].id)

        expect { |b| instance.each(&b) }.to yield_successive_args([dogs[1..1], {}], [dogs[2..2], {}])
      end

      it 'stream data in batches according to the :batch_size option and :finish option' do
        instance = collection_class.new(batch_size: 1, finish: dogs[1].id)

        expect { |b| instance.each(&b) }.to yield_successive_args([dogs[0..0], {}], [dogs[1..1], {}])
      end
    end

    context 'with filter parameters' do
      let(:collection_class) do
        klass = Class.new(described_class)
        klass.base_scope = -> { Dog }
        klass
      end

      after do
        Dog.destroy_all
      end

      it 'filteres by existing attributes' do
        dog_foo = Dog.create!(name: 'foo')
        _dog_bar = Dog.create!(name: 'bar')
        instance = collection_class.new(name: 'foo')

        expect(instance.to_a.size).to eq(1)
        expect { |b| instance.each(&b) }.to yield_successive_args([[dog_foo], { name: 'foo' }])
      end
    end
  end

  describe '#dataset' do
    it 'returns an ActiveRecord::Relation' do
      collection = Class.new(described_class)
      collection.base_scope = -> { Animal.all }
      expect(collection.new.dataset).to be_a(::ActiveRecord::Relation)
    end

    it 'returns an ActiveRecord::Relation with a scope' do
      collection = Class.new(described_class)
      collection.base_scope = -> { Animal.where(name: 'foo') }

      expect(collection.new.dataset).to be_a(::ActiveRecord::Relation)
      expect(collection.new.dataset.to_sql).to eq(Animal.where(name: 'foo').to_sql)
    end
  end

  describe '.inspect' do
    it 'returns the class name' do
      expect(described_class.inspect).to eq('Esse::ActiveRecord::Collection')
    end

    context "when it's an anonymous class" do
      it 'returns super when scope is not defined' do
        klass = Class.new(described_class)
        expect(klass.inspect).to match(/#<Class:.*>/)
      end

      it 'returns custom class name when scope is defined as a relation' do
        klass = Class.new(described_class)
        klass.base_scope = -> { Animal.all }
        expect(klass.inspect).to match('#<Esse::ActiveRecord::Collection__Animal>')
      end

      it 'returns custom class name when scope is defined as a model' do
        klass = Class.new(described_class)
        klass.base_scope = -> { Animal }
        expect(klass.inspect).to match('#<Esse::ActiveRecord::Collection__Animal>')
      end
    end
  end

  describe '.model' do
    it 'returns the model class' do
      collection = Class.new(described_class)
      collection.base_scope = -> { Animal.all }
      expect(collection.model).to eq(Animal)
    end

    it 'returns the model class when scope is defined as a model' do
      collection = Class.new(described_class)
      collection.base_scope = -> { Animal }
      expect(collection.model).to eq(Animal)
    end

    it 'raises an error when scope is not defined' do
      collection = Class.new(described_class)
      expect { collection.model }.to raise_error(NotImplementedError)
    end
  end

  describe '#inspect' do
    it 'returns the class name' do
      expect(described_class.new.inspect).to match(/#<Esse::ActiveRecord::Collection:.*>/)
    end

    context 'when it is an anonymous class' do
      let(:klass) do
        Class.new(described_class)
      end

      it 'returns super when scope is not defined' do
        expect(klass.new.inspect).to match(/#<Class:.*>/)
      end

      it 'returns custom class name when scope is defined as a relation' do
        klass.base_scope = -> { Animal.all }
        expect(klass.new.inspect).to match(/#<Esse::ActiveRecord::Collection__Animal:0x.*>/)
      end

      it 'returns custom class name when scope is defined as a model' do
        klass.base_scope = -> { Animal }
        expect(klass.new.inspect).to match(/#<Esse::ActiveRecord::Collection__Animal:0x.*>/)
      end
    end
  end
end
