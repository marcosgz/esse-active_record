require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Model, '.index_callback' do
  let(:backend_proxy) { double }

  before do
    clear_active_record_hooks
    @models_value_backup = Esse::ActiveRecord::Hooks.models.dup
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

    stub_esse_index(:geographies) do
      repository :state, const: true do
        document do |state, **|
          {
            _id: state.id,
            name: state.name,
            type: 'state',
          }
        end
      end

      repository :county, const: true do
        document do |county, **|
          {
            _id: county.id,
            name: county.name,
            type: 'county',
            routing: county.state_id || 1,
          }.tap do |doc|
            doc[:state] = { id: county.state.id, name: county.state.name } if county.state
          end
        end
      end
    end
  end

  after do
    Esse::ActiveRecord::Hooks.instance_variable_set(:@models, @models_value_backup) # rubocop:disable RSpec/InstanceVariable
    clean_db
  end

  describe '.index_callback' do
    context 'when on :create' do
      let(:index_ok_response) { { 'result' => 'indexed' } }

      it 'register the model class into Esse::ActiveRecord::Hooks.models' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states_index', on: %i[create]
        end
        expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
      end

      it 'index the model on create' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states_index', on: %i[create]
        end
        model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)

        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: model.id,
          index: StatesIndex.index_name,
          body: {name: 'Illinois'},
        ).and_return(index_ok_response)

        model.save
      end

      it 'index the associated model using the block definition' do
        model_class = Class.new(County) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[create] do
            state
          end
        end
        state = build_record(State, name: 'Illinois', id: SecureRandom.uuid)
        county = build_record(model_class, name: 'Cook', state: state)

        expect(GeographiesIndex).to receive(:index).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:index).with(
          id: state.id,
          index: GeographiesIndex.index_name,
          body: {name: 'Illinois', type: 'state'},
        ).and_return(index_ok_response)

        county.save
      end

      it 'does not index when the hooks are globally disabled' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[create]
        end
        model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)

        expect(GeographiesIndex).not_to receive(:index)
        Esse::ActiveRecord::Hooks.without_indexing do
          model.save
        end
      end

      it 'does not index when the hooks are disabled for the model' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[create]
        end
        model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
        expect(GeographiesIndex).not_to receive(:index)
        model_class.without_indexing do
          model.save
        end
      end

      it 'allows to select which indices will not execute indexing callbacks' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states', on: %i[create]
          index_callback 'geographies:state', on: %i[create]
        end
        model = build_record(model_class, name: 'Illinois', id: SecureRandom.uuid)
        expect(GeographiesIndex).not_to receive(:index)
        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: model.id,
          index: StatesIndex.index_name,
          body: {name: 'Illinois'},
        ).and_return(index_ok_response)
        model_class.without_indexing(GeographiesIndex) do
          model.save
        end
      end
    end

    context 'when on :update' do
      let(:index_ok_response) { { 'result' => 'indexed' } }

      it 'register the model class into Esse::ActiveRecord::Hooks.models' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states_index', on: %i[update]
        end
        expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
      end

      it 'index the model on update' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states_index', on: %i[update]
        end
        model = create_record(model_class, name: 'Illinois')

        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: model.id,
          index: StatesIndex.index_name,
          body: {name: 'Illinois'},
        ).and_return(index_ok_response)

        model.touch
      end

      it 'index the associated model using the block definition' do
        model_class = Class.new(County) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[update] do
            state
          end
        end
        state = create_record(State, name: 'Illinois')
        county = create_record(model_class, name: 'Cook', state: state)

        expect(GeographiesIndex).to receive(:index).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:index).with(
          id: state.id,
          index: GeographiesIndex.index_name,
          body: {name: 'Illinois', type: 'state'},
        ).and_return(index_ok_response)

        county.touch
      end

      it 'does not index when the hooks are globally disabled' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[update]
        end
        model = create_record(model_class, name: 'Illinois')

        expect(GeographiesIndex).not_to receive(:index)
        Esse::ActiveRecord::Hooks.without_indexing do
          model.touch
        end
      end

      it 'does not index when the hooks are disabled for the model' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[update]
        end
        model = create_record(model_class, name: 'Illinois')
        expect(GeographiesIndex).not_to receive(:index)
        model_class.without_indexing do
          model.touch
        end
      end

      it 'allows to select which indices will not execute indexing callbacks' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states', on: %i[update]
          index_callback 'geographies:state', on: %i[update]
        end
        model = create_record(model_class, name: 'Illinois')
        expect(GeographiesIndex).not_to receive(:index)
        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: model.id,
          index: StatesIndex.index_name,
          body: {name: 'Illinois'},
        ).and_return(index_ok_response)
        model_class.without_indexing(GeographiesIndex) do
          model.touch
        end
      end
    end

    context 'when on :update with a the document that has a routing key' do
      let(:index_ok_response) { { 'result' => 'indexed' } }
      let(:model_class) do
        Class.new(County) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:county', on: %i[update]
        end
      end
      let(:il) { create_record(State, name: 'Illinois') }
      let(:ny) { create_record(State, name: 'New York') }
      let(:county) { create_record(model_class, name: 'Cook', state: il) }

      it 'indexes the document in new routing and deletes the document from previous routing' do
        expect(GeographiesIndex).to receive(:index).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:index).with(
          id: county.id,
          index: GeographiesIndex.index_name,
          routing: ny.id,
          body: {name: 'Cook', type: 'county', state: { id: ny.id, name: ny.name }},
        ).and_return(index_ok_response)

        expect(GeographiesIndex).to receive(:delete).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:delete).with(
          id: county.id,
          index: GeographiesIndex.index_name,
          routing: il.id,
        ).and_return('result' => 'deleted')

        county.update(state: ny)
      end

      it 'does not delete the document when the routing key is not changed' do
        expect(GeographiesIndex).to receive(:index).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:index).with(
          id: county.id,
          index: GeographiesIndex.index_name,
          routing: il.id,
          body: {name: 'Cook County', type: 'county', state: { id: il.id, name: il.name }},
        ).and_return(index_ok_response)

        expect(GeographiesIndex).not_to receive(:delete)

        county.update(name: 'Cook County')
      end

      it 'does not raise error when the document does not exist' do
        expect(GeographiesIndex).to receive(:index).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:index).with(
          id: county.id,
          index: GeographiesIndex.index_name,
          routing: ny.id,
          body: {name: 'Cook', type: 'county', state: { id: ny.id, name: ny.name }},
        ).and_return(index_ok_response)

        expect(GeographiesIndex).to receive(:delete).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:delete).with(
          id: county.id,
          index: GeographiesIndex.index_name,
          routing: il.id,
        ).and_raise_http_status(404, { 'error' => { 'type' => 'not_found' } })

        county.update(state: ny)
      end
    end

    context 'when on destroy' do
      let(:delete_ok_response) { { 'result' => 'deleted' } }

      it 'register the model class into Esse::ActiveRecord::Hooks.models' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states', on: %i[destroy]
        end
        expect(Esse::ActiveRecord::Hooks.models).to include(model_class)
      end

      it 'removes the document on destroy' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states', on: %i[destroy]
        end
        model = create_record(model_class, name: 'Illinois')
        expect(StatesIndex).to receive(:delete).and_call_original
        expect(StatesIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_return(delete_ok_response)
        model.destroy
      end

      it 'does not raise error when the document does not exist' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[destroy]
        end
        model = create_record(model_class, name: 'Illinois')
        expect(GeographiesIndex).to receive(:delete).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_raise_http_status(404, { 'error' => { 'type' => 'not_found' } })
        expect { model.destroy }.not_to raise_error
      end

      it 'removes the associated model using the block definition' do
        model_class = Class.new(County) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[destroy] do
            state
          end
        end
        state = create_record(State, name: 'Illinois')
        county = create_record(model_class, name: 'Cook', state: state)
        expect(GeographiesIndex).to receive(:delete).and_call_original
        expect(GeographiesIndex).to esse_receive_request(:delete).with(
          id: state.id,
        ).and_return(delete_ok_response)
        county.destroy
      end

      it 'does not perform delete request when the hooks are globally disabled' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[destroy]
        end
        model = create_record(model_class, name: 'Illinois')

        expect(GeographiesIndex).not_to receive(:delete)
        Esse::ActiveRecord::Hooks.without_indexing do
          model.destroy
        end
      end

      it 'does not perform delete request when the hooks are disabled for the model' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'geographies:state', on: %i[destroy]
        end
        model = create_record(model_class, name: 'Illinois')

        expect(GeographiesIndex).not_to receive(:delete)
        model_class.without_indexing do
          model.destroy
        end
      end

      it 'allows to select which indices will NOT perform :delete request during callbacks' do
        model_class = Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states:state', on: %i[destroy]
          index_callback 'geographies:state', on: %i[destroy]
        end
        model = create_record(model_class, name: 'Illinois')

        expect(GeographiesIndex).not_to receive(:delete)
        expect(StatesIndex).to receive(:delete).and_call_original
        expect(StatesIndex).to esse_receive_request(:delete).with(
          id: model.id,
        ).and_return(delete_ok_response)

        model_class.without_indexing(GeographiesIndex) do
          model.destroy
        end
      end
    end
  end
end
