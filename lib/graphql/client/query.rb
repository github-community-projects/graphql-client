require "graphql"
require "graphql/client/node"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "graphql/language/nodes/deep_freeze_ext"

module GraphQL
  module Client
    class Query < Node
      def self.parse(str, schema: nil)
        str = str.strip
        str, fragments = scan_interpolated_fragments(str)

        if str.start_with?("query")
          doc = GraphQL.parse(str)
          doc = doc.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
          doc = doc.replace_fragment_spread(fragments)
          node = doc.definitions.first
        else
          raise ArgumentError, "expected string to be a query:\n#{str}"
        end

        query = new(node.deep_freeze, fragments.values).freeze
        query.node.validate!(schema: schema) if schema
        query
      end
    end
  end
end
