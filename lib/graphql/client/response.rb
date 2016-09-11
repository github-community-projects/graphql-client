require "graphql/client/error"

module GraphQL
  class Client
    # Public: Abstract base class for GraphQL responses.
    #
    #   https://facebook.github.io/graphql/#sec-Response-Format
    class Response
      # Public: Hash of server specific extension metadata.
      attr_reader :extensions

      # Internal: Initialize base class.
      def initialize(extensions: nil)
        @extensions = extensions || {}
      end
    end

    class SuccessfulResponse < Response
      # Public: Wrapped QueryResult of data returned from the server.
      #
      #   https://facebook.github.io/graphql/#sec-Data
      #
      # Returns instance of QueryResult subclass.
      attr_reader :data

      # Internal: Initialize SuccessfulResponse.
      def initialize(data:, **kargs)
        @data = data
        super(**kargs)
      end
    end

    class PartialResponse < SuccessfulResponse
      # Public: Get partial failures from response.
      #
      #   https://facebook.github.io/graphql/#sec-Errors
      #
      # Returns ResponseErrors collection object.
      attr_reader :errors

      # Internal: Initialize PartialResponse.
      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    class FailedResponse < Response
      # Public: Get errors from response.
      #
      #   https://facebook.github.io/graphql/#sec-Errors
      #
      # Returns ResponseErrors collection object.
      attr_reader :errors

      # Internal: Initialize FailedResponse.
      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    class ResponseError < Error
      def initialize(definition, error)
        @request_definition = definition
        @locations = error["locations"]
        super error["message"]
      end
    end

    class ResponseErrors < Error
      include Enumerable

      attr_reader :errors

      def initialize(definition, errors)
        @request_definition = definition
        @errors = errors.map { |error| ResponseError.new(definition, error) }
        super @errors.map(&:message).join(", ")
      end

      def each(&block)
        errors.each(&block)
      end
    end
  end
end
