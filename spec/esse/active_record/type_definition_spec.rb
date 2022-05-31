# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::Plugins::ActiveRecord, '.define_type' do
  describe 'when the type is a model class' do
    it 'define type with only class name without raise an error' do
      expect {
        stub_index(:animals) do
          plugin :active_record

          define_type Animal
        end
      }.not_to raise_error
      expect(AnimalsIndex.type_hash.keys).to match_array(%w[animal])
    end

    it 'define type with name and class name without raise an error' do
      expect {
        stub_index(:animals) do
          plugin :active_record

          define_type :animal, Animal
        end
      }.not_to raise_error
      expect(AnimalsIndex.type_hash.keys).to match_array(%w[animal])
    end

    xit 'define default collection for the class' do
      stub_index(:animals) do
        define_type Animal
      end

      expect(AnimalsIndex.instance_variable_get(:@collection_proc)).to eq('animals')
    end
  end
end
