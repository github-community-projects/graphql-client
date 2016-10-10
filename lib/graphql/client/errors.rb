require "active_support/inflector"

module GraphQL
  class Client
    # Public: Collection of errors associated with GraphQL object type.
    #
    # Inspired by ActiveModel::Errors.
    class Errors
      include Enumerable

      def self.filter_path(errors, path)
        errors = errors.select { |error| path == error["path"][0, path.length] }
        errors = errors.group_by { |error| error["path"][path.length] }
        errors.delete(nil)
        new(errors)
      end

      def self.find_path(errors, path)
        errors = errors.select { |error| path == error["path"][0...-1] }
        errors = errors.group_by { |error| error["path"][path.length] }
        errors.delete(nil)
        new(errors)
      end

      # Internal: Initalize from collection of errors.
      #
      # errors - Array of GraphQL Hash error objects
      def initialize(errors)
        @messages = {}
        @details = {}
        @field_aliases = {}

        errors.each do |field, field_errors|
          field_errors.each do |error|
            @messages[field] ||= []
            @details[field] ||= []

            @messages[field] << error.fetch("message")
            @details[field] << error

            if field.is_a?(String)
              field_alias = ActiveSupport::Inflector.underscore(field)
              @field_aliases[field_alias] = field if field != field_alias
            end
          end
        end

        freeze
      end

      # Public: Access Hash of error messages.
      attr_reader :messages

      # Public: Access Hash of error objects.
      attr_reader :details

      # Public: When passed a symbol or a name of a field, returns an array of
      # errors for the method.
      #
      #   data.errors[:node]  # => ["couldn't find node by id"]
      #   data.errors['node'] # => ["couldn't find node by id"]
      #
      # Returns Array of errors.
      def [](key)
        case key
        when String, Symbol
          key = @field_aliases.fetch(key.to_s, key.to_s)
        end
        messages.fetch(key, [])
      end

      # Public: Iterates through each error key, value pair in the error
      # messages hash. Yields the field and the error for that attribute. If the
      # field has more than one error message, yields once for each error
      # message.
      def each
        return enum_for(:each) unless block_given?
        messages.each_key do |field|
          messages[field].each { |error| yield field, error }
        end
      end

      # Public: Check if there are any errors on a given field.
      #
      #   data.errors.messages # => {"node"=>["couldn't find node by id", "unauthorized"]}
      #   data.errors.include?("node")    # => true
      #   data.errors.include?("version") # => false
      #
      # Returns true if the error messages include an error for the given field,
      # otherwise false.
      def include?(field)
        self[field].any?
      end
      alias has_key? include?
      alias key? include?

      # Public: Count the number of errors on object.
      #
      #   data.errors.messages # => {"node"=>["couldn't find node by id", "unauthorized"]}
      #   data.errors.size     # => 2
      #
      # Returns the number of error messages.
      def size
        values.flatten.size
      end
      alias count size

      # Public: Check if there are no errors on object.
      #
      #   data.errors.messages # => {"node"=>["couldn't find node by id"]}
      #   data.errors.empty?   # => false
      #
      # Returns true if no errors are found, otherwise false.
      def empty?
        size.zero?
      end
      alias blank? empty?

      # Public: Returns all message keys.
      #
      #   data.errors.messages # => {"node"=>["couldn't find node by id"]}
      #   data.errors.values   # => ["node"]
      #
      # Returns Array of String field names.
      def keys
        messages.keys
      end

      # Public: Returns all message values.
      #
      #   data.errors.messages # => {"node"=>["couldn't find node by id"]}
      #   data.errors.values   # => [["couldn't find node by id"]]
      #
      # Returns Array of Array String messages.
      def values
        messages.values
      end

      # Internal: Freeze internal collections.
      def freeze
        @messages.freeze
        @details.freeze
        @field_aliases.freeze
        super
      end
    end
  end
end
