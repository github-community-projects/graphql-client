require "graphql"

module GraphQL
  module Client
    class Node
      attr_reader :node

      attr_reader :fragments

      attr_reader :type

      def initialize(node, fragments)
        @node = node
        @fragments = fragments
        @type = node.query_result_class(shadow: fragments)
      end

      def new(*args)
        type.new(*args)
      end

      def validate!(schema:)
        validator = GraphQL::StaticValidation::Validator.new(
          schema: schema,
          rules: GraphQL::StaticValidation::ALL_RULES - [GraphQL::StaticValidation::FragmentsAreUsed]
        )

        query = GraphQL::Query.new(schema, document: document)

        validator.validate(query).fetch(:errors).each do |error|
          raise error["message"]
        end

        nil
      end
    end
  end
end
