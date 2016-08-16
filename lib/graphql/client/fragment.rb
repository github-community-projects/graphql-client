require "graphql"
require "graphql/client/node"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "graphql/language/nodes/deep_freeze_ext"

module GraphQL
  module Client
    class Fragment < Node
      def self.parse(str, schema: nil)
        str = str.strip
        str, fragments = scan_interpolated_fragments(str)

        if str.start_with?("fragment")
          str = str.sub(/^fragment on /, "fragment __anonymous__ on ")
          doc = GraphQL.parse(str)
          doc = doc.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
          doc = doc.replace_fragment_spread(fragments)
          fragment = doc.definitions.first
          node = GraphQL::Language::Nodes::InlineFragment.new(type: fragment.type, directives: fragment.directives, selections: fragment.selections)
        else
          raise ArgumentError, "expected string to be a fragment:\n#{str}"
        end

        fragment = new(node.deep_freeze, fragments.values).freeze
        fragment.validate!(schema: nil) if schema
        fragment
      end

      def document
        fragment = GraphQL::Language::Nodes::FragmentDefinition.new(name: "foo", type: node.type, directives: node.directives, selections: node.selections)
        GraphQL::Language::Nodes::Document.new(definitions: [fragment])
      end
    end
  end
end
