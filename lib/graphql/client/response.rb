require "graphql/client/error"

module GraphQL
  class Client
    # Public: Abstract base class for GraphQL responses.
    #
    #   https://facebook.github.io/graphql/#sec-Response-Format
    class Response
      # Internal: Initialize Response subclass.
      def self.for(definition, result)
        data, errors, extensions = result.values_at("data", "errors", "extensions")

        Response.new(
          data: definition.new(data, [], errors),
          errors: Errors.new("base" => (errors || []).select { |error| error["path"].nil? }),
          all_errors: Errors.new("base" => errors || []),
          extensions: extensions
        )
      end

      # Public: Wrapped QueryResult of data returned from the server.
      #
      #   https://facebook.github.io/graphql/#sec-Data
      #
      # Returns instance of QueryResult subclass.
      attr_reader :data

      # Public: Get partial failures from response.
      #
      #   https://facebook.github.io/graphql/#sec-Errors
      #
      # Returns ResponseErrors collection object with zero or more errors.
      attr_reader :errors
      attr_reader :all_errors

      # Public: Hash of server specific extension metadata.
      attr_reader :extensions

      # Internal: Initialize base class.
      def initialize(data: nil, all_errors: nil, errors: nil, extensions: nil)
        @data = data
        @all_errors = all_errors || []
        @errors = errors || []
        @extensions = extensions || {}
      end
    end
  end
end
