require 'spec_helper'

class DummyCallbackRepo
  def self.add(*vals)
    Thread.current[:dummy_callback_repo] ||= Set.new
    Thread.current[:dummy_callback_repo].add(*vals)
  end

  def self.all
    (Thread.current[:dummy_callback_repo] || []).to_a
  end

  def self.clear
    Thread.current[:dummy_callback_repo] = nil
  end
end

class DumpTempCallback < Esse::ActiveRecord::Callback
  def call(model)
    DummyCallbackRepo.add [model, options, block_result]
  end
end

class DumpTempCallbackOnCreate < DumpTempCallback; end

class DumpTempCallbackOnUpdate < DumpTempCallback; end

class DumpTempCallbackOnDestroy < DumpTempCallback; end

RSpec.describe Esse::ActiveRecord::Model, '.esse_callback' do
  let(:model_class) do
    Class.new(State) do
      include Esse::ActiveRecord::Model
    end
  end

  before do
    DummyCallbackRepo.clear
    Thread.current[Esse::ActiveRecord::Hooks::STORE_STATE_KEY] = nil
    @__callbacks = Esse::ActiveRecord::Callbacks.instance_variable_get(:@callbacks)
    Esse::ActiveRecord::Callbacks.register_callback(:temp, :create, DumpTempCallbackOnCreate)
    Esse::ActiveRecord::Callbacks.register_callback(:temp, :update, DumpTempCallbackOnUpdate)
    Esse::ActiveRecord::Callbacks.register_callback(:temp, :destroy, DumpTempCallbackOnDestroy)
    @__hooks_models = Esse::ActiveRecord::Hooks.models.dup
    Esse::ActiveRecord::Hooks.models.clear
    stub_cluster_info

    stub_esse_index(:states) do
      repository :state, const: true do
        document do |state, **|
          {
            _id: state.id,
            name: state.name,
          }
        end
      end
    end
  end

  after do
    Esse::ActiveRecord::Hooks.instance_variable_set(:@models, @__hooks_models) # rubocop:disable RSpec/InstanceVariable
    Esse::ActiveRecord::Callbacks.instance_variable_set(:@callbacks, @__callbacks) # rubocop:disable RSpec/InstanceVariable
    clean_db
  end

  describe '.esse_callbacks' do
    it 'returns an empty hash' do
      expect(model_class.esse_callbacks).to eq({})
    end

    it 'returns a frozen hash' do
      expect(model_class.esse_callbacks).to be_frozen
    end
  end

  context 'when on :create' do
    it 'raises an error when the callback is not registered' do
      expect {
        model_class.esse_callback 'states:state', :missing_callback, on: %i[create]
      }.to raise_error(ArgumentError).with_message(/callback missing_callback for create operation not registered/)
    end

    it 'register the model class into Esse::ActiveRecord::Hooks.models' do
      model_class.esse_callback 'states:state', :temp, on: %i[create]
      expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
    end

    it 'register the callback with block definition and custom options' do
      model_class.esse_callback('states:state', :temp, on: %i[create], custom: 'value') { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        'states:state' => a_hash_including(
          temp_on_create: contain_exactly(DumpTempCallbackOnCreate, {custom: 'value'}, an_instance_of(Proc)),
        )
      )
    end

    it 'calls the callback with the model instance' do
      model_class.esse_callback('states:state', :temp, on: %i[create])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      expect(DummyCallbackRepo.all).to include([model, {}, nil])
    end

    it 'does not call the callback when the hooks are globally disabled' do
      model_class.esse_callback('states:state', :temp, on: %i[create])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      Esse::ActiveRecord::Hooks.without_indexing do
        model.save
      end
      expect(DummyCallbackRepo.all).to be_empty
    end

    it 'does not call the callback when the hooks are disabled for the model' do
      model_class.esse_callback('states:state', :temp, on: %i[create])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model_class.without_indexing do
        model.save
      end
      expect(DummyCallbackRepo.all).to be_empty
    end
  end

  context 'when on :update' do
    it 'raises an error when the callback is not registered' do
      expect {
        model_class.esse_callback 'states:state', :missing_callback, on: %i[update]
      }.to raise_error(ArgumentError).with_message(/callback missing_callback for update operation not registered/)
    end

    it 'register the model class into Esse::ActiveRecord::Hooks.models' do
      model_class.esse_callback 'states:state', :temp, on: %i[update]
      expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
    end

    it 'register the callback with block definition and custom options' do
      model_class.esse_callback('states:state', :temp, on: %i[update], custom: 'value') { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        'states:state' => a_hash_including(
          temp_on_update: contain_exactly(DumpTempCallbackOnUpdate, {custom: 'value'}, an_instance_of(Proc)),
        )
      )
    end

    it 'calls the callback with the model instance' do
      model_class.esse_callback('states:state', :temp, on: %i[update])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      model.update(name: 'New Illinois')
      expect(DummyCallbackRepo.all).to include([model, {}, nil])
    end

    it 'does not call the callback when the hooks are globally disabled' do
      model_class.esse_callback('states:state', :temp, on: %i[update])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      Esse::ActiveRecord::Hooks.without_indexing do
        model.update(name: 'New Illinois')
      end
      expect(DummyCallbackRepo.all).to be_empty
    end

    it 'does not call the callback when the hooks are disabled for the model' do
      model_class.esse_callback('states:state', :temp, on: %i[update])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      model_class.without_indexing do
        model.update(name: 'New Illinois')
      end
      expect(DummyCallbackRepo.all).to be_empty
    end
  end

  context 'when on :destroy' do
    it 'raises an error when the callback is not registered' do
      expect {
        model_class.esse_callback 'states:state', :missing_callback, on: %i[destroy]
      }.to raise_error(ArgumentError).with_message(/callback missing_callback for destroy operation not registered/)
    end

    it 'register the model class into Esse::ActiveRecord::Hooks.models' do
      model_class.esse_callback 'states:state', :temp, on: %i[destroy]
      expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
    end

    it 'register the callback with block definition and custom options' do
      model_class.esse_callback('states:state', :temp, on: %i[destroy], custom: 'value') { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        'states:state' => a_hash_including(
          temp_on_destroy: contain_exactly(DumpTempCallbackOnDestroy, {custom: 'value'}, an_instance_of(Proc)),
        )
      )
    end

    it 'calls the callback with the model instance' do
      model_class.esse_callback('states:state', :temp, on: %i[destroy])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      model.destroy
      expect(DummyCallbackRepo.all).to include([model, {}, nil])
    end

    it 'does not call the callback when the hooks are globally disabled' do
      model_class.esse_callback('states:state', :temp, on: %i[destroy])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      Esse::ActiveRecord::Hooks.without_indexing do
        model.destroy
      end
      expect(DummyCallbackRepo.all).to be_empty
    end

    it 'does not call the callback when the hooks are disabled for the model' do
      model_class.esse_callback('states:state', :temp, on: %i[destroy])
      model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
      model.save
      model_class.without_indexing do
        model.destroy
      end
      expect(DummyCallbackRepo.all).to be_empty
    end
  end
end
