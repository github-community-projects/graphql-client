require "json"
require "net/http"
require "uri"

module GraphQL
  class Client
    class HTTP
      attr_reader :uri

      # GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")
      def initialize(uri, &block)
        @uri = ::URI.parse(uri)
        class_eval(&block) if block_given?
      end

      def headers(query)
        {}
      end

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
