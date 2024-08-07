# frozen_string_literal: true

module Esse
  module ActiveRecord
    class Callback
      attr_reader :repo, :options, :block_result

      def initialize(repo:, block_result: nil, with: nil, **kwargs)
        @repo = repo
        @with = with
        @options = kwargs
        @block_result = block_result
      end

      def call(model)
        raise NotImplementedError, 'You must implement #call method'
      end
    end

    module Callbacks
      class << self
        def to_h
          @callbacks || {}.freeze
        end

        def register_callback(identifier, operation, callback_class)
          unless callback_class < Esse::ActiveRecord::Callback
            raise ArgumentError, 'callback_class must be a subclass of Esse::ActiveRecord::Callback'
          end

          key = [operation, identifier].join('_').to_sym

          @callbacks = @callbacks ? @callbacks.dup : {}
          if @callbacks.key?(key)
            raise ArgumentError, "callback #{identifier} for #{operation} operation already registered"
          end

          @callbacks[key] = callback_class
        ensure
          @callbacks&.freeze
        end

        def registered?(identifier, operation)
          return false unless @callbacks

          key = [operation, identifier].join('_').to_sym
          @callbacks.key?(key)
        end

        def fetch!(identifier, operation)
          key = [operation, identifier].join('_').to_sym
          if registered?(identifier, operation)
            [key, @callbacks[key]]
          else
            raise ArgumentError, "callback #{identifier} for #{operation} operation not registered"
          end
        end
      end
    end
  end
end

require_relative 'callbacks/indexing_on_create'
require_relative 'callbacks/indexing_on_update'
require_relative 'callbacks/indexing_on_destroy'
require_relative 'callbacks/update_lazy_attribute'
