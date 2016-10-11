require "graphql/client/hash_with_indifferent_access"

module GraphQL
  class Client
    # Public: Collection of errors associated with GraphQL object type.
    #
    # Inspired by ActiveModel::Errors.
    class Errors
      include Enumerable

      def self.normalize_error_paths(data, errors)
        errors.each do |error|
          path = ["data"]
          current = data
          error.fetch("path", []).each do |key|
            break unless current
            path << key
            current = current[key]
          end
          error["normalizedPath"] = path
        end
        errors
      end

      # Internal: Initalize from collection of errors.
      #
      # errors - Array of GraphQL Hash error objects
      # path   - Array of String|Integer fields to data
      # all    - Boolean flag if all nested errors should be available
      def initialize(errors = [], path = [], all = false)
        @ast_path = path
        @all = all
        @raw_errors = errors
      end

      def all
        if @all
          self
        else
          self.class.new(@raw_errors, @ast_path, true)
        end
      end

      def filter_by_path(field)
        self.class.new(@raw_errors, @ast_path + [field], @all)
      end

      # Public: Access Hash of error messages.
      def messages
        return @messages if defined? @messages

        messages = {}

        details.each do |field, errors|
          messages[field] ||= []
          errors.each do |error|
            messages[field] << error.fetch("message")
          end
        end

        @messages = HashWithIndifferentAccess.new(messages)
      end

      # Public: Access Hash of error objects.
      def details
        return @details if defined? @details

        details = {}

        @raw_errors.each do |error|
          path = error.fetch("normalizedPath", [])
          expected_path = @all ? path[0, @ast_path.length] : path[0...-1]
          next unless @ast_path == expected_path

          field = path[@ast_path.length]
          next unless field

          details[field] ||= []
          details[field] << error
        end

        @details = HashWithIndifferentAccess.new(details)
      end

      # Public: When passed a symbol or a name of a field, returns an array of
      # errors for the method.
      #
      #   data.errors[:node]  # => ["couldn't find node by id"]
      #   data.errors['node'] # => ["couldn't find node by id"]
      #
      # Returns Array of errors.
      def [](key)
        messages.fetch(key, [])
      end

      # Public: Iterates through each error key, value pair in the error
      # messages hash. Yields the field and the error for that attribute. If the
      # field has more than one error message, yields once for each error
      # message.
      def each
        return enum_for(:each) unless block_given?
        messages.keys.each do |field|
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

      # Public: Display console friendly representation of errors collection.
      #
      # Returns String.
      def inspect
        "#<#{self.class} @messages=#{messages.inspect} @details=#{details.inspect}>"
      end
    end
  end
end
