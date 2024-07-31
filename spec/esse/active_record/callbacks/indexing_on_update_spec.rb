# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Callbacks::IndexingOnUpdate do
  describe '.initialize' do
    let(:repo) { instance_double(Esse::Repository) }

    it 'sets @with' do
      callback = described_class.new(repo: repo, with: :update)
      expect(callback.instance_variable_get(:@with)).to eq(:update)
    end

    it 'sets options' do
      callback = described_class.new(repo: repo, foo: :bar)
      expect(callback.options).to eq(foo: :bar)
    end
  end

  describe '.call' do
    let(:ok_response) { { 'result' => 'indexed' } }
    let(:state_class) do
      Class.new(State) do
        include Esse::ActiveRecord::Model
        index_callback 'states:state', on: :update
      end
    end
    let!(:state) { create_record(state_class, name: 'Illinois') }

    before do
      clear_active_record_hooks
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
      clean_db
    end

    context 'when update_with is :index' do
      it 'indexes the update record' do
        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: state.id,
          index: StatesIndex.index_name,
          body: {name: 'IL'},
        ).and_return(ok_response)

        state.update!(name: 'IL')
      end
    end

    context 'when update_with is :update' do
      let(:state_class) do
        Class.new(State) do
          include Esse::ActiveRecord::Model
          index_callback 'states:state', on: :update, with: :update
        end
      end

      it 'updates the update record when it exist' do
        expect(StatesIndex).to receive(:update).and_call_original
        expect(StatesIndex).to esse_receive_request(:update).with(
          id: state.id,
          index: StatesIndex.index_name,
          body: {doc: { name: 'IL' } },
        ).and_return(ok_response)

        state.update!(name: 'IL')
      end

      it 'indexes the update record when it does not exist' do
        expect(StatesIndex).to receive(:update).and_call_original
        expect(StatesIndex).to esse_receive_request(:update).with(
          id: state.id,
          index: StatesIndex.index_name,
          body: {doc: { name: 'IL' } },
        ).and_raise_http_status(404, { 'error' => { 'type' => 'not_found' } })

        expect(StatesIndex).to receive(:index).and_call_original
        expect(StatesIndex).to esse_receive_request(:index).with(
          id: state.id,
          index: StatesIndex.index_name,
          body: {name: 'IL'},
        ).and_return(ok_response)

        state.update!(name: 'IL')
      end
    end

    context 'when not calling with in a repository with lazy attributes' do
      before do
        StatesIndex::State.lazy_document_attribute :total_counties do |docs|
          ::County.where(state_id: docs.map(&:id)).group(:state_id).count
        end
      end

      after do
        StatesIndex::State.instance_variable_set(:@lazy_document_attributes, {}.freeze)
      end

      it { expect(StatesIndex::State.lazy_document_attributes).not_to be_empty }

      it 'updates the record using :update action to avoid losing lazy attributes' do
        expect(StatesIndex).to receive(:update).and_call_original
        expect(StatesIndex).to esse_receive_request(:update).with(
          id: state.id,
          index: StatesIndex.index_name,
          body: {doc: { name: 'IL' } },
        ).and_return(ok_response)

        state.update!(name: 'IL')
      end
    end
  end
end
