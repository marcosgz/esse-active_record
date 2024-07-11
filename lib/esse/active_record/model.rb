# frozen_string_literal: true

module Esse
  module ActiveRecord
    module Model
      extend ActiveSupport::Concern

      module ClassMethods
        extend Esse::Deprecations::Deprecate

        def esse_callbacks
          @esse_callbacks ||= {}.freeze
        end

        def esse_callback(index_repo_name, operation_name, on: %i[create update destroy], **options, &block)
          @esse_callbacks = esse_callbacks.dup
          cb_if = options.delete(:if)
          cb_unless = options.delete(:unless)
          if_enabled = -> {
            (cb_if.nil? || (cb_if.respond_to?(:call) ? instance_exec(&cb_if) : send(cb_if))) &&
              (cb_unless.nil? || (cb_unless.respond_to?(:call) ? !instance_exec(&cb_unless) : !send(cb_unless))) &&
              Esse::ActiveRecord::Hooks.enabled?(index_repo_name) &&
              Esse::ActiveRecord::Hooks.enabled_for_model?(self.class, index_repo_name)
          }

          Array(on).each do |event|
            identifier, klass = Esse::ActiveRecord::Callbacks.fetch!(operation_name, event)

            if @esse_callbacks.dig(index_repo_name, identifier)
              raise ArgumentError, format('index repository %<name>p already registered %<op>s operation', name: index_repo_name, op: operation_name)
            end

            @esse_callbacks[index_repo_name] = @esse_callbacks[index_repo_name]&.dup || {}
            @esse_callbacks[index_repo_name][identifier] = [klass, options, block]

            after_commit(on: event, if: if_enabled) do
              klass, options, block = self.class.esse_callbacks.fetch(index_repo_name).fetch(identifier)
              options[:repo] = Esse::ActiveRecord::Hooks.resolve_index_repository(index_repo_name)
              options[:block_result] = instance_exec(&block) if block.respond_to?(:call)
              instance = klass.new(**options)
              instance.call(self)
            end
          end

          Esse::ActiveRecord::Hooks.register_model(self)
        ensure
          @esse_callbacks&.each_value { |v| v.freeze }&.freeze
        end

        # Define callback for create/update/delete elasticsearch index document after model commit.
        #
        # @param [String] index_repo_name The path of index and repository name.
        #   For example a index with a single repository named `users` is `users`. And a index with
        #   multiple repositories named `animals` and `dog` as the repository name is `animals/dog`.
        #   For namespace, use `/` as the separator.
        # @raise [ArgumentError] when the repo and events are already registered
        # @raise [ArgumentError] when the specified index have multiple repos
        def index_callback(index_repo_name, on: %i[create update destroy], with: nil, **options, &block)
          if with
            Array(on).each do |event|
              if on == :update
                esse_callback(index_repo_name, :indexing, on: event, with: with, **options, &block)
              else
                esse_callback(index_repo_name, :indexing, on: event, **options, &block)
              end
            end
          else
            esse_callback(index_repo_name, :indexing, on: on, **options, &block)
          end
        end

        def update_lazy_attribute_callback(index_repo_name, attribute_name, on: %i[create update destroy], **options, &block)
          options[:attribute_name] = attribute_name
          esse_callback(index_repo_name, :update_lazy_attribute, on: on, **options, &block)
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

        def index_callbacks(*args, **options, &block)
          index_callback(*args, **options, &block)
        end
        deprecate :index_callbacks, :index_callback, 2024, 12

        def esse_index_repos
          esse_callbacks
        end
        deprecate :esse_index_repos, :esse_callbacks, 2024, 12
      end
    end
  end
end
