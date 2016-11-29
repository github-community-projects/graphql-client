require "graphql"
require "graphql/client/document_types"

module GraphQL
  class Client
    # Internal: Insert __typename field selections into query.
    module QueryTypename
      # Internal: Insert __typename field selections into query.
      #
      # Skips known types when schema is provided.
      #
      # document - GraphQL::Language::Nodes::Document to modify
      # schema - Optional Map of GraphQL::Language::Nodes::Node to GraphQL::Type
      #
      # Returns nothing.
      def self.insert_typename_fields(document, types: {})
        on_selections = ->(node, _parent) do
          return unless node.selections.any?

          type = types[node]
          case type && type.unwrap
          when NilClass, GraphQL::InterfaceType, GraphQL::UnionType
            names = node_flatten_selections(node.selections).map { |s| s.respond_to?(:name) ? s.name : nil }
            names = Set.new(names.compact)

            unless names.include?("__typename")
              node.selections = [GraphQL::Language::Nodes::Field.new(name: "__typename")] + node.selections
            end
          end
        end

        visitor = GraphQL::Language::Visitor.new(document)
        visitor[GraphQL::Language::Nodes::Field].leave << on_selections
        visitor[GraphQL::Language::Nodes::FragmentDefinition].leave << on_selections
        visitor[GraphQL::Language::Nodes::OperationDefinition].leave << on_selections
        visitor.visit

        nil
      end

      def self.node_flatten_selections(selections)
        selections.flat_map do |selection|
          case selection
          when GraphQL::Language::Nodes::Field
            selection
          when GraphQL::Language::Nodes::InlineFragment
            node_flatten_selections(selection.selections)
          else
            []
          end
        end
      end
    end
  end
end
