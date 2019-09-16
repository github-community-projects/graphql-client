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
        unless schema.is_a?(GraphQL::Schema) || (schema.is_a?(Class) && schema < GraphQL::Schema)
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
          if definition = type_stack.argument_definitions.last
            existing_type = variables[node.name.to_sym]

            if existing_type && existing_type.unwrap != definition.type.unwrap
              raise GraphQL::Client::ValidationError, "$#{node.name} was already declared as #{existing_type.unwrap}, but was #{definition.type.unwrap}"
            elsif !(existing_type && existing_type.kind.non_null?)
              variables[node.name.to_sym] = definition.type
            end
          end
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
        case type.kind.name
        when "NON_NULL"
          GraphQL::Language::Nodes::NonNullType.new(of_type: variable_node(type.of_type))
        when "LIST"
          GraphQL::Language::Nodes::ListType.new(of_type: variable_node(type.of_type))
        else
          GraphQL::Language::Nodes::TypeName.new(name: type.graphql_name)
        end
      end
    end
  end
end
