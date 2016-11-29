require "graphql"

module GraphQL
  class Client
    # Public: Document type analyzer.
    module DocumentTypes
      def self.analyze_types(schema, document)
        unless schema.is_a?(GraphQL::Schema)
          raise TypeError, "expected schema to be a GraphQL::Schema, but was #{schema.class}"
        end

        visitor = GraphQL::Language::Visitor.new(document)
        type_stack = GraphQL::StaticValidation::TypeStack.new(schema, visitor)

        fields = {}

        visitor[GraphQL::Language::Nodes::OperationDefinition] << ->(node, _parent) do
          fields[node] = type_stack.object_types.last
        end
        visitor[GraphQL::Language::Nodes::FragmentDefinition] << ->(node, _parent) do
          fields[node] = type_stack.object_types.last
        end
        visitor[GraphQL::Language::Nodes::Field] << ->(node, _parent) do
          fields[node] = type_stack.field_definitions.last.type.unwrap
        end
        visitor.visit

        fields
      end
    end
  end
end
