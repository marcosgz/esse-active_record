# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Callbacks::UpdateLazyAttribute do
  let(:repo) { instance_double(Esse::Repository) }

  describe '.initialize' do
    it 'sets attribute_name' do
      callback = described_class.new(repo: repo, attribute_name: :foo)
      expect(callback.attribute_name).to eq(:foo)
    end

    it 'sets options' do
      callback = described_class.new(repo: repo, attribute_name: :foo, foo: :bar)
      expect(callback.options).to eq(foo: :bar)
    end
  end

  describe '.call' do
    let(:ok_response) { { 'result' => 'indexed' } }
    let(:county_class) do
      Class.new(County) do
        include Esse::ActiveRecord::Model
        update_lazy_attribute_callback 'states:state', :total_counties do
          state_id
        end
      end
    end

    before do
      stub_cluster_info
      clear_active_record_hooks
      stub_esse_index(:states) do
        repository :state, const: true do
          document do |state, **|
            {
              _id: state.id,
              name: state.name,
            }
          end
          lazy_document_attribute :total_counties do |docs|
            ::County.where(state_id: docs.map(&:id)).group(:state_id).count
          end
        end
      end
    end

    after do
      clean_db
    end

    it 'bulk update the state :total_counties attribute when the county is created' do
      state = create_record(State, name: 'Illinois')
      county = build_record(county_class, name: 'Cook', state: state)
      expect(StatesIndex::State).to receive(:update_documents_attribute).with(:total_counties, [state.id], {}).and_call_original
      expect(StatesIndex).to esse_receive_request(:bulk).with(
        index: StatesIndex.index_name,
        body: [
          { update: { _id: state.id, data: { doc: { total_counties: 1 } } } }
        ]
      ).and_return(ok_response)

      county.save!
    end
  end
end
