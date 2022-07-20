# frozen_string_literal: true

module Esse
  module ActiveRecord
    module Model
      extend ActiveSupport::Concern

      def self.inherited(subclass)
        super
        subclass.esse_index_repos = esse_index_repos.dup
      end

      module ClassMethods
        attr_reader :esse_index_repos

        # Define callback for create/update/delete elasticsearch index document after model commit.
        #
        # @raise [ArgumentError] when the repo and events are already registered
        # @raise [ArgumentError] when the specified index have multiple repos
        def index_callbacks(index_or_repo, on: %i[create update destroy], **options, &block)
          @esse_index_repos ||= {}
          repo = index_or_repo <= ::Esse::Repository ? index_or_repo : index_or_repo.repo

          operation_name = :index
          if esse_index_repos.dig(repo, operation_name)
            raise ArgumentError, "index repository #{repo} already registered #{operation_name} operation"
          end

          esse_index_repos[repo] ||= {}
          esse_index_repos[repo][operation_name] = {
            record: (block || -> { self }),
            options: options,
          }

          Esse::ActiveRecord::Hooks.register_model(self)

          if_enabled = -> { Esse::ActiveRecord::Hooks.enabled?(repo) && Esse::ActiveRecord::Hooks.enabled_for_model?(self.class, repo) }
          (on & %i[create update]).each do |event|
            after_commit(on: event, if: if_enabled) do
              opts = self.class.esse_index_repos.fetch(repo).fetch(operation_name)
              record = opts.fetch(:record)
              record = instance_exec(&record) if record.respond_to?(:call)
              document = repo.serialize(record)
              repo.elasticsearch.index_document(document, **opts[:options]) if document
              true
            end
          end
          (on & %i[destroy]).each do |event|
            after_commit(on: event, if: if_enabled) do
              opts = self.class.esse_index_repos.fetch(repo).fetch(operation_name)
              record = opts.fetch(:record)
              record = instance_exec(&record) if record.respond_to?(:call)
              document = repo.serialize(record)
              repo.elasticsearch.delete_document(document, **opts[:options]) if document
              true
            end
          end
        end

        # Disable indexing for the block execution on model level
        # Example:
        #  User.without_indexing { }
        #  User.without_indexing(UsersIndex, AccountsIndex::User) { }
        def without_indexing(*repos)
          Esse::ActiveRecord::Hooks.without_indexing_for_model(self, *repos) do
            yield
          end
        end
      end
    end
  end
end
