# frozen_string_literal: true

module Esse
  module ActiveRecord
    module Hooks
      STORE_STATE_KEY = :esse_active_record_hooks

      class << self
        def register_model(model_class)
          @models ||= []
          @models |= [model_class]
        end

        def models
          @models || []
        end

        def model_names
          models.map(&:to_s)
        end

        # Global enable indexing callbacks. If no repository is specified, all repositories will be enabled.
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @return [void]
        def enable!(*repos)
          filter_repositories(*repos).each do |repo|
            state[:repos][repo] = true
          end
        end

        # Global disable indexing callbacks. If no repository is specified, all repositories will be disabled.
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @return [void]
        def disable!(*repos)
          filter_repositories(*repos).each do |repo|
            state[:repos][repo] = false
          end
        end

        # Check if the given repository is enabled for indexing. If no repository is specified, all repositories will be checked.
        #
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @return [Boolean]
        def disabled?(*repos)
          filter_repositories(*repos).all? { |repo| !state[:repos][repo] }
        end

        # Check if the given repository is enabled for indexing. If no repository is specified, all repositories will be checked.
        #
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @return [Boolean]
        def enabled?(*repos)
          filter_repositories(*repos).all? { |repo| state[:repos][repo] }
        end

        # Enable model indexing callbacks for the given model. If no repository is specified, all repositories will be enabled.
        #
        # @param model_class [Class]
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @raise [ArgumentError] if model repository is not registered for the given model
        # @return [void]
        def enable_model!(model_class, *repos)
          ensure_registered_model_class!(model_class)
          filter_model_repositories(model_class, *repos).each do |repo|
            state[:models][model_class][repo] = true
          end
        end

        # Disable model indexing callbacks for the given model. If no repository is specified, all repositories will be disabled.
        #
        # @param model_class [Class]
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @raise [ArgumentError] if model repository is not registered for the given model
        # @return [void]
        def disable_model!(model_class, *repos)
          ensure_registered_model_class!(model_class)
          filter_model_repositories(model_class, *repos).each do |repo|
            state[:models][model_class][repo] = false
          end
        end

        def ensure_registered_model_class!(model_class)
          return if registered_model_class?(model_class)

          raise ArgumentError, "Model class #{model_class} is not registered. The model should inherit from Esse::ActiveRecord::Model and have a `index_callbacks' callback defined"
        end

        # Check if the given model is enabled for indexing. If no repository is specified, all repositories will be checked.
        #
        # @param model_class [Class]
        # @param repos [Array<String, Esse::Index, Esse::Repo>]
        # @return [Boolean]
        def enabled_for_model?(model_class, *repos)
          return false unless registered_model_class?(model_class)

          filter_model_repositories(model_class, *repos).all? do |repo|
            state.dig(:models, model_class, repo) != false
          end
        end

        # Disable indexing callbacks execution for the block execution.
        # Example:
        #  Esse::ActiveRecord::Hooks.without_indexing { User.create! }
        #  Esse::ActiveRecord::Hooks.without_indexing(UsersIndex, AccountsIndex.repo(:user)) { User.create! }
        def without_indexing(*repos)
          state_before_disable = state[:repos].dup
          disable!(*repos)

          yield
        ensure
          state[:repos] = state_before_disable
        end

        # Disable model indexing callbacks execution for the block execution for the given model.
        # Example:
        #  BroadcastChanges.without_indexing_for_model(User) { }
        #  BroadcastChanges.without_indexing_for_model(User, :datasync, :other) { }
        def without_indexing_for_model(model_class, *repos)
          state_before_disable = state[:models].dig(model_class).dup
          disable_model!(model_class, *repos)
          yield
        ensure
          if state_before_disable.nil?
            state[:models].delete(model_class)
          else
            state[:models][model_class] = state_before_disable
          end
        end

        def resolve_index_repository(name)
          index_name, repo_name = name.to_s.underscore.split('::').join('/').split(':', 2)
          if index_name !~ /(I|_i)ndex$/ && index_name !~ /_index\/([\w_]+)$/
            index_name = format('%<index_name>s_index', index_name: index_name)
          end
          klass = index_name.classify.constantize
          return klass if klass <= Esse::Repository

          repo_name.present? ? klass.repo(repo_name) : klass.repo
        end

        private

        def all_repos
          models.flat_map(&method(:model_repos)).uniq
        end

        # Returns a list of all repositories for the given model
        # @return [Array<Symbol>]
        def model_repos(model_class)
          expand_index_repos(*model_class.esse_index_repos.keys)
        end

        # Returns a list of all repositories for the given model
        # If no repository is specified, all repositories will be returned.
        # @return [Array<*Esse::Repository>] List of repositories
        def filter_repositories(*repos)
          (expand_index_repos(*repos) & all_repos).presence || all_repos
        end

        # Return repositorys for the given model. If no repository is specified, all repositories will be returned.
        #
        # @param model_class [Class]
        # @param repos [Array<*Esse::Repository>] List of repositories to check for the given model
        # @return [Array<*Esse::Repository>] List of repositories
        def filter_model_repositories(model_class, *repos)
          model_repos = model_repos(model_class) & all_repos
          (expand_index_repos(*repos) & model_repos).presence || model_repos
        end

        def expand_index_repos(*repos)
          repos.flat_map do |repo_name|
            case repo_name
            when Class
              repo_name <= Esse::Index ? repo_name.repo_hash.values : repo_name
            when String, Symbol
              resolve_index_repository(repo_name)
            else
              raise ArgumentError, "Invalid index or repository name: #{repo_name.inspect}"
            end
          end
        end

        # Check if model class is registered
        # @return [Boolean] true if model class is registered
        def registered_model_class?(model_class)
          models.include?(model_class)
        end

        # Data Structure:
        #
        # repos: { <Esse::Repository class> => <true|false>, ... }
        # models: {
        #   <ActiveRecord::Base class> => {
        #     <Esse::Repository class> => <true|false>
        #   }
        # }
        def state
          global_store[STORE_STATE_KEY] ||= {
            repos: all_repos.map { |k| [k, true] }.to_h, # Control global state of the index repository level
            models: Hash.new { |h, k| h[k] = {} }, # Control the state of the model & index repository level
          }
        end

        def global_store
          Thread.current
        end
      end
    end
  end
end
