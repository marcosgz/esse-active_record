require 'spec_helper'

class DummyIndexableModel
  extend ActiveModel::Callbacks
  include Esse::ActiveRecord::Model

  attr_reader :event

  define_model_callbacks :commit, :rollback

  %i[create update destroy].each do |event|
    define_method(event) do |succeed: true|
      @event = event
      succeed ? run_commit_callbacks : run_rollback_callbacks
    end
  end

  def run_commit_callbacks
    run_callbacks :commit
  end

  def run_rollback_callbacks
    run_callbacks :rollback
  end
end

RSpec.describe Esse::ActiveRecord::Model, model_hooks: true do
  let(:backend_proxy) { double }

  before do
    Thread.current[Esse::ActiveRecord::Hooks::STORE_STATE_KEY] = nil
    @models_value_backup = Esse::ActiveRecord::Hooks.models.dup
    Esse::ActiveRecord::Hooks.models.clear
  end

  after do
    Esse::ActiveRecord::Hooks.instance_variable_set(:@models, @models_value_backup) # rubocop:disable RSpec/InstanceVariable
  end

  describe '.index_callbacks' do
    shared_examples 'index document callbacks' do |event|
      context "when on #{event}" do
        let(:document) { double }

        before do
          stub_index(:dummies) do
            repository :dummy, const: true do
            end
          end
        end

        it 'register the model class into Esse::ActiveRecord::Hooks.models' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
        end

        it 'index the model on create' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          model = model_class.new
          expect(DummiesIndex.repo).to receive(:serialize).with(model).and_return(document)
          expect(DummiesIndex.repo).to receive(:elasticsearch).and_return(backend_proxy)
          expect(backend_proxy).to receive(:index_document).with(document, {}).and_return(:ok)
          model.send(event)
        end

        it 'index the associated model using the block definition' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event] do
              association
            end

            protected

            def association
              :other
            end
          end
          model = model_class.new
          expect(DummiesIndex.repo).to receive(:serialize).with(:other).and_return(document)
          expect(DummiesIndex.repo).to receive(:elasticsearch).and_return(backend_proxy)
          expect(backend_proxy).to receive(:index_document).with(document, {}).and_return(:ok)
          model.send(event)
        end

        it 'does not index when the hooks are globally disabled' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          model = model_class.new

          Esse::ActiveRecord::Hooks.without_indexing do
            expect(DummiesIndex.repo).not_to receive(:serialize)
            expect(DummiesIndex.repo).not_to receive(:elasticsearch)
            model.send(event)
          end
        end

        it 'does not index when the hooks are disabled for the model' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          model = model_class.new
          model_class.without_indexing do
            expect(DummiesIndex.repo).not_to receive(:serialize)
            expect(DummiesIndex.repo).not_to receive(:elasticsearch)
            model.send(event)
          end
        end

        it 'allows to select which indices will not execute indexing callbacks' do
          stub_index(:others) do
            repository(:other, const: true) {}
          end

          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies', on: [event]
            index_callbacks 'others:other', on: [event]
          end
          model = model_class.new
          model_class.without_indexing(DummiesIndex) do
            expect(DummiesIndex::Dummy).not_to receive(:serialize)
            expect(DummiesIndex::Dummy).not_to receive(:index_document)
            expect(OthersIndex::Other).to receive(:serialize).with(model).and_return(document)
            expect(OthersIndex::Other).to receive(:elasticsearch).and_return(backend_proxy)
            expect(backend_proxy).to receive(:index_document).with(document, {}).and_return(:ok)
            model.send(event)
          end
        end
      end
    end

    include_examples 'index document callbacks', :create
    include_examples 'index document callbacks', :update

    context 'when on destroy' do
      let(:document) { double }

      before do
        stub_index(:dummies) do
          repository :dummy, const: true do
          end
        end
      end

      it 'register the model class into Esse::ActiveRecord::Hooks.models' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
      end

      it 'index the model on create' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new
        expect(DummiesIndex.repo).to receive(:serialize).with(model).and_return(document)
        expect(DummiesIndex.repo).to receive(:elasticsearch).and_return(backend_proxy)
        expect(backend_proxy).to receive(:delete_document).with(document, {}).and_return(:ok)
        model.destroy
      end

      it 'index the associated model using the block definition' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy] do
            association
          end

          protected

          def association
            :other
          end
        end
        model = model_class.new
        expect(DummiesIndex.repo).to receive(:serialize).with(:other).and_return(document)
        expect(DummiesIndex.repo).to receive(:elasticsearch).and_return(backend_proxy)
        expect(backend_proxy).to receive(:delete_document).with(document, {}).and_return(:ok)
        model.destroy
      end

      it 'does not index when the hooks are globally disabled' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new

        Esse::ActiveRecord::Hooks.without_indexing do
          expect(DummiesIndex.repo).not_to receive(:serialize)
          expect(DummiesIndex.repo).not_to receive(:elasticsearch)
          model.destroy
        end
      end

      it 'does not index when the hooks are disabled for the model' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new
        model_class.without_indexing do
          expect(DummiesIndex.repo).not_to receive(:serialize)
          expect(DummiesIndex.repo).not_to receive(:elasticsearch)
          model.destroy
        end
      end

      it 'allows to select which indices will not execute indexing callbacks' do
        stub_index(:others) do
          repository(:other, const: true) {}
        end

        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies:dummy', on: %i[destroy]
          index_callbacks 'others:other', on: %i[destroy]
        end
        model = model_class.new
        model_class.without_indexing(DummiesIndex) do
          expect(DummiesIndex::Dummy).not_to receive(:serialize)
          expect(DummiesIndex::Dummy).not_to receive(:delete_document)
          expect(OthersIndex::Other).to receive(:serialize).with(model).and_return(document)
          expect(OthersIndex::Other).to receive(:elasticsearch).and_return(backend_proxy)
          expect(backend_proxy).to receive(:delete_document).with(document, {}).and_return(:ok)
          model.destroy
        end
      end
    end
  end
end
