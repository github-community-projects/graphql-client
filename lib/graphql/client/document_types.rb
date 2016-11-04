require "graphql"

module GraphQL
  class Client
    # Public: Document type analyzer.
    module DocumentTypes
      # :nodoc:
      class Validation
        attr_reader :fields

        def initialize
          @fields = {}
        end

        def new
          self
        end

        def validate(context)
          context.visitor[GraphQL::Language::Nodes::FragmentDefinition] << ->(node, _parent) do
            @fields[node] = context.object_types[-1]
          end
          context.visitor[GraphQL::Language::Nodes::Field] << ->(_node, parent) do
            @fields[parent] = context.object_types[-2].unwrap
          end
          context.visitor[GraphQL::Language::Nodes::FragmentSpread] << ->(_node, parent) do
            @fields[parent] = context.object_types[-1].unwrap
          end
        end
      end

      def self.analyze_types(schema, document)
        unless schema.is_a?(GraphQL::Schema)
          raise TypeError, "expected schema to be a GraphQL::Schema, but was #{schema.class}"
        end

        validation = Validation.new
        validator = GraphQL::StaticValidation::Validator.new(schema: schema, rules: [validation])
        query = GraphQL::Query.new(schema, document: document)
        validator.validate(query)
        validation.fields
      end
    end
  end
end
