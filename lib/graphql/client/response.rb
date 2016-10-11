require "graphql/client/errors"

module GraphQL
  class Client
    # Public: Abstract base class for GraphQL responses.
    #
    #   https://facebook.github.io/graphql/#sec-Response-Format
    class Response
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
      # Returns Errors collection object with zero or more errors.
      attr_reader :errors

      # Public: Hash of server specific extension metadata.
      attr_reader :extensions

      # Internal: Initialize base class.
      def initialize(data: nil, errors: Errors.new, extensions: {})
        @data = data
        @errors = errors
        @extensions = extensions
      end
    end
  end
end
