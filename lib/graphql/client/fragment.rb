require "graphql"

module GraphQL
  module Client
    class Fragment < Node
      def document
        fragment = GraphQL::Language::Nodes::FragmentDefinition.new(name: "foo", type: node.type, directives: node.directives, selections: node.selections)
        GraphQL::Language::Nodes::Document.new(definitions: [fragment])
      end
    end
  end
end
