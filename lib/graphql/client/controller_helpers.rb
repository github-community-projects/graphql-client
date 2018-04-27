# frozen_string_literal: true
require "graphql/client"
require "graphql/client/query_error"

module GraphQL
  class Client
    module ControllerHelpers
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def graphql_parse(query)
          Rails.application.config.graphql.client.parse(query)
        end
      end

      private

      # Private: The GraphQL::Client instance to be used for graphql_query.
      #
      # Returns a GraphQL::Client instance.
      def graphql_client
        Rails.application.config.graphql.client
      end

      # Private: Define request scoped helper method for making GraphQL queries.
      #
      # Examples
      #
      #   data = graphql_query(ViewerQuery)
      #   data.viewer.login #=> "josh"
      #
      # definition - A query or mutation operation GraphQL::Client::Definition.
      #              Client.parse("query { version }") returns a definition.
      # variables - Optional set of variables to use during the operation.
      #             (default: {})
      #
      # Returns a structured query result or raises if the request failed.
      def graphql_query(definition, variables = {})
        response = graphql_client.query(definition, variables: variables, context: graphql_context)

        if response.errors.any?
          raise GraphQL::Client::QueryError.new(response.errors[:data].join(", "))
        else
          response.data
        end
      end

      # Private: Useful helper method for tracking GraphQL context data to pass
      # along to the network adapter.
      def graphql_context
        { }
      end
    end
  end
end
