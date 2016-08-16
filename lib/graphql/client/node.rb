require "active_support/inflector"
require "graphql"
require "graphql/client/error"
require "graphql/language/nodes/query_result_class_ext"

module GraphQL
  module Client
    class Node
      def self.scan_interpolated_fragments(str)
        fragments, index = {}, 1
        str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
          index += 1
          name = "__fragment#{index}__"
          fragments[name.to_sym] = ActiveSupport::Inflector.constantize($1).node
          "...#{name}"
        }
        return str, fragments
      end

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
          raise GraphQL::Client::Error, error["message"]
        end

        nil
      end
    end
  end
end
