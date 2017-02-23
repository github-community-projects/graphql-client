# frozen_string_literal: true
require "graphql"

module GraphQL
  class Client
    # Internal: Detect variables used in a definition.
    module DefinitionVariables
      # Internal: Detect all variables used in a given operation or fragment
      # definition.
      #
      # schema - A GraphQL::Schema
      # document - A GraphQL::Language::Nodes::Document to scan
      # definition_name - A String definition name. Defaults to anonymous definition.
      #
      # Returns a Hash[Symbol] to GraphQL::Type objects.
      def self.variables(schema, document, definition_name = nil)
        unless schema.is_a?(GraphQL::Schema)
          raise TypeError, "expected schema to be a GraphQL::Schema, but was #{schema.class}"
        end

        unless document.is_a?(GraphQL::Language::Nodes::Document)
          raise TypeError, "expected document to be a GraphQL::Language::Nodes::Document, but was #{document.class}"
        end

        sliced_document = GraphQL::Language::DefinitionSlice.slice(document, definition_name)

        visitor = GraphQL::Language::Visitor.new(sliced_document)
        type_stack = GraphQL::StaticValidation::TypeStack.new(schema, visitor)

        variables = {}

        visitor[GraphQL::Language::Nodes::VariableIdentifier] << ->(node, parent) do
          definition = type_stack.argument_definitions.last
          variables[node.name.to_sym] = definition.type if definition
        end

        visitor.visit

        variables
      end

      # Internal: Detect all variables used in a given operation or fragment
      # definition.
      #
      # schema - A GraphQL::Schema
      # document - A GraphQL::Language::Nodes::Document to scan
      # definition_name - A String definition name. Defaults to anonymous definition.
      #
      # Returns a Hash[Symbol] to VariableDefinition objects.
      def self.operation_variables(schema, document, definition_name = nil)
        variables(schema, document, definition_name).map { |name, type|
          GraphQL::Language::Nodes::VariableDefinition.new(name: name.to_s, type: variable_node(type))
        }
      end

      # Internal: Get AST node for GraphQL type.
      #
      # type - A GraphQL::Type
      #
      # Returns GraphQL::Language::Nodes::Type.
      def self.variable_node(type)
        case type
        when GraphQL::NonNullType
          GraphQL::Language::Nodes::NonNullType.new(of_type: variable_node(type.of_type))
        when GraphQL::ListType
          GraphQL::Language::Nodes::ListType.new(of_type: variable_node(type.of_type))
        else
          GraphQL::Language::Nodes::TypeName.new(name: type.name)
        end
      end
    end
  end
end
