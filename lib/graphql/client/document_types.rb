# frozen_string_literal: true
require "graphql"
require "graphql/client/type_stack"

module GraphQL
  class Client
    # Internal: Use schema to detect definition and field types.
    module DocumentTypes
      class AnalyzeTypesVisitor < GraphQL::Language::Visitor
        prepend GraphQL::Client::TypeStack
        attr_reader :fields

        def initialize(*a, **kw)
          @fields = {}
          super
        end

        def on_operation_definition(node, _parent)
          @fields[node] = @object_types.last
          super
        end

        def on_fragment_definition(node, _parent)
          @fields[node] = @object_types.last
          super
        end

        def on_inline_fragment(node, _parent)
          @fields[node] = @object_types.last
          super
        end

        def on_field(node, _parent)
          @fields[node] = @field_definitions.last.type
          super
        end
      end

      # Internal: Detect all types used in a given document
      #
      # schema - A GraphQL::Schema
      # document - A GraphQL::Language::Nodes::Document to scan
      #
      # Returns a Hash[Language::Nodes::Node] to GraphQL::Type objects.
      def self.analyze_types(schema, document)
        unless schema.is_a?(GraphQL::Schema) || (schema.is_a?(Class) && schema < GraphQL::Schema)
          raise TypeError, "expected schema to be a GraphQL::Schema, but was #{schema.class}"
        end

        unless document.is_a?(GraphQL::Language::Nodes::Document)
          raise TypeError, "expected schema to be a GraphQL::Language::Nodes::Document, but was #{document.class}"
        end

        visitor = AnalyzeTypesVisitor.new(document, schema: schema)
        visitor.visit
        visitor.fields
      rescue StandardError => err
        if err.is_a?(TypeError)
          raise
        end
        # FIXME: TypeStack my crash on invalid documents
        visitor.fields
      end
    end
  end
end
