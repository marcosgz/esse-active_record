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

  def id
    @id ||= SecureRandom.uuid
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
    stub_cluster_info
  end

  after do
    Esse::ActiveRecord::Hooks.instance_variable_set(:@models, @models_value_backup) # rubocop:disable RSpec/InstanceVariable
  end

  describe '.index_callbacks' do
    shared_examples 'index document callbacks' do |event|
      context "when on #{event}" do
        let(:index_ok_response) { { 'result' => 'created' } }

        before do
          stub_esse_index(:dummies) do
            repository :dummy, const: true do
              document do |dummy, **|
                {
                  _id: dummy.id,
                  name: "Dummy #{dummy.id}"
                }
              end
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

          expect(DummiesIndex).to receive(:index).and_call_original
          expect(DummiesIndex).to esse_receive_request(:index).with(
            id: model.id,
            index: DummiesIndex.index_name,
            body: {name: "Dummy #{model.id}"},
          ).and_return(index_ok_response)

          model.send(event)
        end

        it 'index the associated model using the block definition' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event] do
              association
            end

            def association
              @association ||= DummyIndexableModel.new
            end
          end
          model = model_class.new

          expect(DummiesIndex).to receive(:index).and_call_original
          expect(DummiesIndex).to esse_receive_request(:index).with(
            id: model.association.id,
            index: DummiesIndex.index_name,
            body: {name: "Dummy #{model.association.id}"},
          ).and_return(index_ok_response)

          model.send(event)
        end

        it 'does not index when the hooks are globally disabled' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          model = model_class.new

          expect(DummiesIndex).not_to receive(:index)
          Esse::ActiveRecord::Hooks.without_indexing do
            model.send(event)
          end
        end

        it 'does not index when the hooks are disabled for the model' do
          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies_index', on: [event]
          end
          model = model_class.new
          expect(DummiesIndex).not_to receive(:index)
          model_class.without_indexing do
            model.send(event)
          end
        end

        it 'allows to select which indices will not execute indexing callbacks' do
          stub_esse_index(:others) do
            repository(:other, const: true) do
              document do |other, **|
                {
                  _id: other.id,
                  name: "Other #{other.id}"
                }
              end
            end
          end

          model_class = Class.new(DummyIndexableModel) do
            index_callbacks 'dummies', on: [event]
            index_callbacks 'others:other', on: [event]
          end
          model = model_class.new
          expect(DummiesIndex).not_to receive(:index)
          expect(OthersIndex).to receive(:index).and_call_original
          expect(OthersIndex).to esse_receive_request(:index).with(
            id: model.id,
            index: OthersIndex.index_name,
            body: {name: "Other #{model.id}"},
          ).and_return(index_ok_response)
          model_class.without_indexing(DummiesIndex) do
            model.send(event)
          end
        end
      end
    end

    include_examples 'index document callbacks', :create
    # include_examples 'index document callbacks', :update

    context 'when on destroy' do
      let(:delete_ok_response) { { 'result' => 'deleted' } }

      before do
        stub_esse_index(:dummies) do
          repository :dummy, const: true do
            document do |dummy, **|
              {
                _id: dummy.id,
                name: "Dummy #{dummy.id}"
              }
            end
          end
        end
      end

      it 'register the model class into Esse::ActiveRecord::Hooks.models' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
      end

      it 'removes the document on destroy' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new
        expect(DummiesIndex).to receive(:delete).and_call_original
        expect(DummiesIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_return(delete_ok_response)
        model.destroy
      end

      it 'does not raise error when the document does not exist' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new
        expect(DummiesIndex).to receive(:delete).and_call_original
        expect(DummiesIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_raise_http_status(404, { 'error' => { 'type' => 'not_found' } })
        expect { model.destroy }.not_to raise_error
      end

      it 'removes the associated model using the block definition' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy] do
            association
          end

          def association
            @association ||= DummyIndexableModel.new
          end
        end
        model = model_class.new
        expect(DummiesIndex).to receive(:delete).and_call_original
        expect(DummiesIndex).to esse_receive_request(:delete).with(
          id: model.association.id,
        ).and_return(delete_ok_response)
        model.destroy
      end

      it 'does not perform delete request when the hooks are globally disabled' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new

        expect(DummiesIndex).not_to receive(:delete)
        Esse::ActiveRecord::Hooks.without_indexing do
          model.destroy
        end
      end

      it 'does not perform delete request when the hooks are disabled for the model' do
        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies_index', on: %i[destroy]
        end
        model = model_class.new

        expect(DummiesIndex).not_to receive(:delete)
        model_class.without_indexing do
          model.destroy
        end
      end

      it 'allows to select which indices will NOT perform :delete request during callbacks' do
        stub_esse_index(:others) do
          repository(:other, const: true) do
            document do |other, **|
              {
                _id: other.id,
                name: "Other #{other.id}"
              }
            end
          end
        end

        model_class = Class.new(DummyIndexableModel) do
          index_callbacks 'dummies:dummy', on: %i[destroy]
          index_callbacks 'others:other', on: %i[destroy]
        end

        model = model_class.new
        expect(DummiesIndex).not_to receive(:delete)
        expect(OthersIndex).to receive(:delete).and_call_original
        expect(OthersIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_return(delete_ok_response)

        model_class.without_indexing(DummiesIndex) do
          model.destroy
        end
      end
    end
  end
end
