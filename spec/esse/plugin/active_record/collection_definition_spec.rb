# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Esse::Plugins::ActiveRecord, '.collection' do # rubocop:disable RSpec/FilePath
  describe 'index collection definition' do
    context 'when the type is a model class' do
      it 'define collection with only class name without raise an error' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection Animal
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::ActiveRecord::Collection
        expect(AnimalsIndex.repo.dataset).to be_a(::ActiveRecord::Relation)
      end

      it 'define collection with name and class name without raise an error' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            repository :cat do
              collection Animal
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo(:cat).instance_variable_get(:@collection_proc)).to be < Esse::ActiveRecord::Collection
        expect(AnimalsIndex.repo(:cat).dataset).to be_a(::ActiveRecord::Relation)
      end

      it 'define collection with an activerecord relation' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection Animal.all
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::ActiveRecord::Collection
        expect(AnimalsIndex.repo.dataset).to be_a(::ActiveRecord::Relation)
      end

      it 'define a collection with custom batch_size' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection(Animal, batch_size: 10)
          end
        }.not_to raise_error
        expect(col = AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::ActiveRecord::Collection
        expect(col.batch_size).to eq(10)
      end

      it 'evaluates the block in the Esse::ActiveRecord::Collection' do
        expect {
          stub_index(:animals) do
            plugin :active_record

            collection Animal do
              def self.foo
                'bar'
              end
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc).foo).to eq('bar')
      end
    end
  end
end
