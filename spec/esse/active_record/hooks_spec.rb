require 'spec_helper'

RSpec.describe Esse::ActiveRecord::Hooks do
  let(:animal_model) do
    Class.new do
      include Esse::ActiveRecord::Model

      Esse::ActiveRecord::Hooks.register_model(self)
      instance_variable_set(:@esse_index_repos, {
        AnimalsIndex::Cat => {},
        AnimalsIndex::Dog => {},
      })
    end
  end

  let(:user_model) do
    Class.new do
      include Esse::ActiveRecord::Model

      Esse::ActiveRecord::Hooks.register_model(self)
      instance_variable_set(:@esse_index_repos, {
        UsersIndex::User => {},
      })
    end
  end

  let(:repositories) { AnimalsIndex.repo_hash.values + UsersIndex.repo_hash.values }

  before do
    stub_esse_index(:animals) do
      plugin :active_record

      repository :cat, const: true do
      end
      repository :dog, const: true do
      end
    end

    stub_esse_index(:users) do
      plugin :active_record

      repository :user, const: true do
      end
    end

    described_class.send(:global_store)[Esse::ActiveRecord::Hooks::STORE_STATE_KEY] = nil
    allow(described_class).to receive(:all_repos).and_return(repositories)
  end

  describe '.resolve_index_repository' do
    specify do
      expect(described_class.resolve_index_repository('users')).to eq(UsersIndex.repo(:user))
    end

    specify do
      expect(described_class.resolve_index_repository('users_index')).to eq(UsersIndex.repo(:user))
    end

    specify do
      expect(described_class.resolve_index_repository('users_index:user')).to eq(UsersIndex.repo(:user))
    end

    specify do
      expect(described_class.resolve_index_repository('users:user')).to eq(UsersIndex.repo(:user))
    end

    specify do
      expect(described_class.resolve_index_repository('UsersIndex')).to eq(UsersIndex.repo(:user))
    end

    specify do
      expect(described_class.resolve_index_repository('UsersIndex::User')).to eq(UsersIndex.repo(:user))
    end

    specify do
      stub_const('Foo::V1::UsersIndex', UsersIndex)
      expect(described_class.resolve_index_repository('Foo::V1::UsersIndex')).to eq(Foo::V1::UsersIndex.repo(:user))
      expect(described_class.resolve_index_repository('foo/v1/users')).to eq(Foo::V1::UsersIndex.repo(:user))
      expect(described_class.resolve_index_repository('foo/v1/users_index')).to eq(Foo::V1::UsersIndex.repo(:user))
      expect(described_class.resolve_index_repository('foo/v1/users_index/user')).to eq(Foo::V1::UsersIndex.repo(:user))
      expect(described_class.resolve_index_repository('foo/v1/users:user')).to eq(Foo::V1::UsersIndex.repo(:user))
    end
  end

  describe '.disable!' do
    it 'disables the indexing of all repositories' do
      expect(described_class.enabled?).to be true
      repositories.each do |repo|
        expect(described_class.enabled?(repo)).to be true
        expect(described_class.disabled?(repo)).to be false
      end

      described_class.disable!

      expect(described_class.enabled?).to be false
      repositories.each do |repo|
        expect(described_class.enabled?(repo)).to be false
        expect(described_class.disabled?(repo)).to be true
      end
    end

    it 'disables the indexing for one or more indices' do
      expect(described_class.enabled?(AnimalsIndex)).to be true
      expect(described_class.enabled?(UsersIndex)).to be true

      described_class.disable!(UsersIndex)

      expect(described_class.enabled?(AnimalsIndex)).to be true
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
      expect(described_class.enabled?(UsersIndex)).to be false
      expect(described_class.enabled?(UsersIndex::User)).to be false
    end

    it 'disables the indexing for one or more repositories' do
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
      expect(described_class.enabled?(UsersIndex::User)).to be true

      described_class.disable!(AnimalsIndex::Cat)

      expect(described_class.enabled?(AnimalsIndex::Cat)).to be false
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
      expect(described_class.enabled?(UsersIndex::User)).to be true

      expect(described_class.disabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.disabled?(AnimalsIndex::Dog)).to be false
      expect(described_class.disabled?(UsersIndex::User)).to be false
    end
  end

  describe '.enable!' do
    before do
      described_class.disable!
    end

    it 'enables the indexing of all repositories' do
      expect(described_class.enabled?).to be false
      repositories.each do |repo|
        expect(described_class.enabled?(repo)).to be false
        expect(described_class.disabled?(repo)).to be true
      end

      described_class.enable!

      expect(described_class.enabled?).to be true
      repositories.each do |repo|
        expect(described_class.enabled?(repo)).to be true
        expect(described_class.disabled?(repo)).to be false
        expect(described_class.enabled?(repo)).to be true
        expect(described_class.disabled?(repo)).to be false
      end
    end

    it 'disables the indexing for one or more indices' do
      expect(described_class.enabled?(AnimalsIndex)).to be false
      expect(described_class.enabled?(UsersIndex)).to be false

      described_class.enable!(UsersIndex)

      expect(described_class.enabled?(AnimalsIndex)).to be false
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be false
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be false
      expect(described_class.enabled?(UsersIndex)).to be true
      expect(described_class.enabled?(UsersIndex::User)).to be true
    end

    it 'enables the indexing for one or more repositories' do
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be false
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be false
      expect(described_class.enabled?(UsersIndex::User)).to be false

      described_class.enable!(AnimalsIndex::Cat)

      expect(described_class.enabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be false
      expect(described_class.enabled?(UsersIndex::User)).to be false
      expect(described_class.disabled?(AnimalsIndex::Cat)).to be false
      expect(described_class.disabled?(AnimalsIndex::Dog)).to be true
      expect(described_class.disabled?(UsersIndex::User)).to be true
    end
  end

  describe '.without_indexing' do
    specify do
      expect(described_class.enabled?).to be true
      described_class.without_indexing do
        expect(described_class.enabled?).to be false
        expect(described_class.disabled?).to be true
      end
      expect(described_class.enabled?).to be true
    end

    specify do
      expect(described_class.enabled?).to be true
      described_class.without_indexing(AnimalsIndex::Cat, UsersIndex::User) do
        expect(described_class.enabled?(AnimalsIndex::Cat)).to be false
        expect(described_class.enabled?(UsersIndex::User)).to be false
        expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
      end
      expect(described_class.enabled?(UsersIndex::User)).to be true
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
    end

    specify do
      expect(described_class.enabled?).to be true
      described_class.without_indexing(AnimalsIndex) do
        expect(described_class.enabled?(AnimalsIndex)).to be false
        expect(described_class.enabled?(AnimalsIndex::Cat)).to be false
        expect(described_class.enabled?(AnimalsIndex::Dog)).to be false
        expect(described_class.enabled?(UsersIndex::User)).to be true
        expect(described_class.enabled?(UsersIndex)).to be true
      end
      expect(described_class.enabled?(UsersIndex::User)).to be true
      expect(described_class.enabled?(AnimalsIndex::Cat)).to be true
      expect(described_class.enabled?(AnimalsIndex::Dog)).to be true
    end

    specify do
      described_class.disable!
      expect(described_class.disabled?).to be true
      described_class.without_indexing do
        expect(described_class.enabled?).to be false
        expect(described_class.disabled?).to be true
      end
      expect(described_class.disabled?).to be true
    end
  end

  describe '.enable_model! and .disable_model!' do
    it 'raises an error if the model class does not registered' do
      expect {
        described_class.enable_model!(Class.new)
      }.to raise_error(/is not registered. The model should inherit from Esse::ActiveRecord::Model/)
    end

    it 'enables and disables the indexing callbacks for the given model' do
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true

      described_class.disable_model!(animal_model)
      expect(described_class.enabled_for_model?(animal_model)).to be false
      expect(described_class.enabled_for_model?(user_model)).to be true

      described_class.enable_model!(animal_model)
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true
    end

    it 'enables the indexing callbacks for the given model and repository' do
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true

      described_class.disable_model!(animal_model, AnimalsIndex::Cat)
      expect(described_class.enabled_for_model?(animal_model)).to be false
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be false
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true

      described_class.enable_model!(animal_model, AnimalsIndex::Cat)
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be true
    end
  end

  describe '.without_indexing_for_model' do
    specify do
      expect(described_class.enabled?).to be true
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true
      described_class.without_indexing_for_model(animal_model) do
        expect(described_class.enabled?).to be true
        expect(described_class.enabled_for_model?(animal_model)).to be false
        expect(described_class.enabled_for_model?(user_model)).to be true
      end
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true
    end

    specify do
      expect(described_class.enabled?).to be true
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true
      described_class.without_indexing_for_model(animal_model, AnimalsIndex::Cat) do
        expect(described_class.enabled?).to be true
        expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be false
        expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be true
        expect(described_class.enabled_for_model?(user_model)).to be true
      end
      expect(described_class.enabled_for_model?(animal_model)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be true
      expect(described_class.enabled_for_model?(user_model)).to be true
    end

    it 'reverts the to initial state after block execution' do
      described_class.disable_model!(animal_model, AnimalsIndex::Dog)
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be false
      described_class.without_indexing_for_model(animal_model, AnimalsIndex::Cat) do
        expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be false
        expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be false
      end
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Cat)).to be true
      expect(described_class.enabled_for_model?(animal_model, AnimalsIndex::Dog)).to be false
    end
  end
end
