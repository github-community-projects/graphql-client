# frozen_string_literal: true
require "active_support/inflector"
require "forwardable"

module GraphQL
  class Client
    # Public: Implements a read only hash where keys can be accessed by
    # strings, symbols, snake or camel case.
    #
    # Also see ActiveSupport::HashWithIndifferentAccess.
    class HashWithIndifferentAccess
      extend Forwardable
      include Enumerable

      def initialize(hash = {})
        @hash = hash
        @aliases = {}

        hash.each_key do |key|
          if key.is_a?(String)
            key_alias = ActiveSupport::Inflector.underscore(key)
            @aliases[key_alias] = key if key != key_alias
          end
        end

        freeze
      end

      def_delegators :@hash, :each, :empty?, :inspect, :keys, :length, :size, :to_h, :to_hash, :values

      def [](key)
        @hash[convert_value(key)]
      end

      def fetch(key, *args, &block)
        @hash.fetch(convert_value(key), *args, &block)
      end

      def key?(key)
        @hash.key?(convert_value(key))
      end
      alias include? key?
      alias has_key? key?
      alias member? key?

      def each_key(&block)
        @hash.each_key { |key| yield convert_value(key) }
      end

      private

      def convert_value(key)
        case key
        when String, Symbol
          key = key.to_s
          @aliases.fetch(key, key)
        else
          key
        end
      end
    end
  end
end
