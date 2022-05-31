# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::Plugins::ActiveRecord, '.collection' do
  describe 'index collection definition' do
    context 'when the type is a model class' do
      it 'define collectcollectioncollectionion with only class name without raise an error' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection Animal
          end
        }.not_to raise_error
        expect(AnimalsIndex.instance_variable_get(:@collection_proc).keys).to match_array(%i[animal])
        expect(AnimalsIndex.instance_variable_get(:@collection_proc)[:animal]).to be < Esse::ActiveRecord::Collection
      end

      it 'define collection with name and class name without raise an error' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection :cat, Animal
          end
        }.not_to raise_error
        expect(AnimalsIndex.instance_variable_get(:@collection_proc).keys).to match_array(%i[cat])
        expect(AnimalsIndex.instance_variable_get(:@collection_proc)[:cat]).to be < Esse::ActiveRecord::Collection
      end
    end
  end
end
