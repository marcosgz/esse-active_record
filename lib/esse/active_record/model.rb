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
        # @param [String] index_repo_name The path of index and repository name.
        #   For example a index with a single repository named `users` is `users`. And a index with
        #   multiple repositories named `animals` and `dog` as the repository name is `animals/dog`.
        #   For namespace, use `/` as the separator.
        # @raise [ArgumentError] when the repo and events are already registered
        # @raise [ArgumentError] when the specified index have multiple repos
        def index_callbacks(index_repo_name, on: %i[create update destroy], **options, &block)
          @esse_index_repos ||= {}

          operation_name = :index
          if esse_index_repos.dig(index_repo_name, operation_name)
            raise ArgumentError, format('index repository %<name>p already registered %<op>s operation', name: index_repo_name, op: operation_name)
          end

          esse_index_repos[index_repo_name] ||= {}
          esse_index_repos[index_repo_name][operation_name] = {
            record: block || -> { self },
            options: options,
          }

          Esse::ActiveRecord::Hooks.register_model(self)

          if_enabled = -> { Esse::ActiveRecord::Hooks.enabled?(index_repo_name) && Esse::ActiveRecord::Hooks.enabled_for_model?(self.class, index_repo_name) }
          (on & %i[create]).each do |event|
            after_commit(on: event, if: if_enabled) do
              opts = self.class.esse_index_repos.fetch(index_repo_name).fetch(operation_name)
              record = opts.fetch(:record)
              record = instance_exec(&record) if record.respond_to?(:call)
              repo = Esse::ActiveRecord::Hooks.resolve_index_repository(index_repo_name)
              document = repo.serialize(record)
              repo.index.index(document, **opts[:options]) if document
              true
            end
          end
          (on & %i[update]).each do |event|
            after_commit(on: event, if: if_enabled) do
              opts = self.class.esse_index_repos.fetch(index_repo_name).fetch(operation_name)
              record = opts.fetch(:record)
              record = instance_exec(&record) if record.respond_to?(:call)
              repo = Esse::ActiveRecord::Hooks.resolve_index_repository(index_repo_name)
              document = repo.serialize(record)
              next true unless document

              repo.index.index(document, **opts[:options])
              next true unless document.routing

              prev_record = self.class.new(attributes.merge(previous_changes.transform_values(&:first))).tap(&:readonly!)
              prev_document = repo.serialize(prev_record)

              next true unless prev_document
              next true if [prev_document.id, prev_document.routing].include?(nil)
              next true if prev_document.routing == document.routing
              next true if prev_document.id != document.id

              begin
                repo.index.delete(prev_document, **opts[:options])
              rescue Esse::Transport::NotFoundError
              end

              true
            end
          end
          (on & %i[destroy]).each do |event|
            after_commit(on: event, if: if_enabled) do
              opts = self.class.esse_index_repos.fetch(index_repo_name).fetch(operation_name)
              record = opts.fetch(:record)
              record = instance_exec(&record) if record.respond_to?(:call)
              repo = Esse::ActiveRecord::Hooks.resolve_index_repository(index_repo_name)
              document = repo.serialize(record)
              repo.index.delete(document, **opts[:options]) if document
              true
            rescue Esse::Transport::NotFoundError
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
