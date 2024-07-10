# frozen_string_literal: true

module Esse
  module ActiveRecord
    class Callback
      attr_reader :options, :block

      def initialize(**kwargs, &block)
        @options = kwargs
        @block = block
      end

      def call
        raise NotImplementedError, 'You must implement #call method'
      end
    end

    module Callbacks
      class << self
        def to_h
          @callbacks || {}
        end

        def register_callback(identifier, operation, callback_class)
          unless callback_class < Esse::ActiveRecord::Callback
            raise ArgumentError, 'callback_class must be a subclass of Esse::ActiveRecord::Callback'
          end

          key = :"#{identifier}_on_#{operation}"

          @callbacks ||= {}
          if @callbacks.key?(key)
            raise ArgumentError, "callback #{identifier} for #{operation} operation already registered"
          end

          @callbacks[key] = callback_class
        end

        def registered?(identifier, operation)
          return false unless @callbacks

          @callbacks.key?(:"#{identifier}_on_#{operation}")
        end

        def fetch(identifier, operation)
          @callbacks[:"#{identifier}_on_#{operation}"]
        end
      end
    end
  end
end

require_relative 'callbacks/indexing_on_create'
require_relative 'callbacks/indexing_on_update'
require_relative 'callbacks/indexing_on_destroy'
