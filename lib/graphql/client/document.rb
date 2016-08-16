require "graphql"
require "graphql/client/fragment"
require "graphql/client/node"
require "graphql/client/query"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"

module GraphQL
  module Client
    class Document < Node
      def self.parse(str, schema: nil)
        str = str.strip
        str, fragments = scan_interpolated_fragments(str)

        document = GraphQL.parse(str)
        document = document.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))

        document.definitions.each do |definition|
          fragments[definition.name.to_sym] = definition if definition.is_a?(FragmentDefinition)
        end

        document = document.replace_fragment_spread(fragments)

        document.definitions.inject({}) do |doc, definition|
          name = definition.name.to_sym

          case definition
          when OperationDefinition
            query = GraphQL::Client::Query.new(definition.deep_freeze, fragments.values).freeze
            query.validate!(schema: schema) if schema
            doc[name] = query

          when FragmentDefinition
            definition = InlineFragment.new(type: definition.type, directives: definition.directives, selections: definition.selections)
            fragment = GraphQL::Client::Fragment.new(definition.deep_freeze, fragments.values).freeze
            fragment.validate!(schema: schema) if schema
            doc[name] = fragment
          end

          doc
        end
      end
    end
  end
end
