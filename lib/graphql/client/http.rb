require "json"
require "net/http"
require "uri"

module GraphQL
  class Client
    # Public: Basic HTTP network adapter.
    #
    #   GraphQL::Client::Client.new(
    #     fetch: GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")
    #   )
    #
    # Assumes GraphQL endpoint follows the express-graphql endpoint conventions.
    #   https://github.com/graphql/express-graphql#http-usage
    #
    # Production applications should consider implementing there own network
    # adapter. This class exists for trivial stock usage and allows for minimal
    # request header configuration.
    class HTTP
      # Public: Create HTTP adapter instance for a single GraphQL endpoint.
      #
      #   GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/") do
      #     def headers(query)
      #       { "User-Agent": "My Client" }
      #     end
      #   end
      #
      # uri - String endpoint URI
      # block - Optional block to configure class
      def initialize(uri, &block)
        @uri = URI.parse(uri)
        class_eval(&block) if block_given?
      end

      # Public: Parsed endpoint URI
      #
      # Returns URI.
      attr_reader :uri

      # Public: Extension point for subclasses to set custom request headers.
      #
      # query - The GraphQL::Client::Query being sent
      #
      # Returns Hash of String header names and values.
      def headers(query)
        {}
      end

      # Public: Make an HTTP request for GraphQL query.
      #
      # Implements Client's "fetch" adapter interface.
      #
      # query - The GraphQL::Client::Query being sent
      #
      # Returns { "data" => ... , "errors" => ... } Hash.
      def call(query)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri.request_uri)

        request["Accept"] = "application/json"
        request["Content-Type"] = "application/json"
        headers(query).each { |name, value| request[name] = value }

        body = {}
        body["query"] = query.to_s
        body["variables"] = JSON.generate(query.variables) if query.variables.any?
        body["operationName"] = query.operation_name if query.operation_name
        request.body = JSON.generate(body)

        response = http.request(request)
        JSON.parse(response.body)
      end
    end
  end
end
