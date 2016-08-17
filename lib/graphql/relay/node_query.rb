require "graphql"
require "graphql/language/nodes/deep_freeze_ext"

module GraphQL
  module Relay
    NODE_QUERY = GraphQL.parse(<<-'GRAPHQL').definitions.first.deep_freeze
      query($id: ID!) {
        node(id: $id) {
          ...NodeFragment
        }
      }
    GRAPHQL

    def self.NodeQuery(fragment)
      fragment = GraphQL::Language::Nodes::FragmentDefinition.new(name: "NodeFragment", type: fragment.type, selections: fragment.selections)
      GraphQL::Language::Nodes::Document.new(definitions: [NODE_QUERY, fragment])
    end
  end
end
