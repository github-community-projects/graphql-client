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

        if data && errors
          PartialResponse.new(
            data: definition.new(data),
            errors: ResponseErrors.new(definition, errors),
            extensions: extensions
          )
        elsif data && !errors
          SuccessfulResponse.new(
            data: definition.new(data),
            extensions: extensions
          )
        elsif !data && errors
          FailedResponse.new(
            errors: ResponseErrors.new(definition, errors),
            extensions: extensions
          )
        else
          FailedResponse.new(
            errors: ResponseErrors.new(definition, [{ "message" => "invalid GraphQL response" }])
          )
        end
      end

      # Public: Hash of server specific extension metadata.
      attr_reader :extensions

      # Internal: Initialize base class.
      def initialize(extensions: nil)
        @extensions = extensions || {}
      end
    end

    # Public: A successful response means the query executed without any errors
    # and returned all the requested data.
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

    # Public: A partial response means the query executed with some errors but
    # returned all non-nullable fields. PartialResponse is still considered a
    # SuccessfulResponse as it returns data and the client may still proceed
    # with its normal render flow.
    class PartialResponse < SuccessfulResponse
      # Public: Get partial failures from response.
      #
      #   https://facebook.github.io/graphql/#sec-Errors
      #
      # Returns ResponseErrors collection object with zero or more errors.
      attr_reader :errors

      # Internal: Initialize PartialResponse.
      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    # Public: A failed response returns no data and at least one error message.
    # Cases may likely be a query validation error, missing authorization,
    # or internal server crash.
    class FailedResponse < Response
      # Public: Get errors from response.
      #
      #   https://facebook.github.io/graphql/#sec-Errors
      #
      # Returns ResponseErrors collection object with one or more errors.
      attr_reader :errors

      # Internal: Initialize FailedResponse.
      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    # Public: An error received from the server on execution.
    #
    # Extends StandardError hierarchy so you may raise this instance.
    #
    # Examples
    #
    #   raise response.errors.first
    #
    class ResponseError < Error
      # Internal: Initialize ResponseError.
      def initialize(definition, error)
        @request_definition = definition
        @locations = error["locations"]
        super error["message"]
      end
    end

    # Public: A collection of errors received from the server on execution.
    #
    # Extends StandardError hierarchy so you may raise this instance.
    #
    # Examples
    #
    #   raise response.errors
    #
    class ResponseErrors < Error
      include Enumerable

      attr_reader :errors

      # Internal: Initialize ResponseErrors.
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
