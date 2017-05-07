# frozen_string_literal: true
require "graphql"
require "set"

module GraphQL
  class Client
    # A QueryResult struct wraps data returned from a GraphQL response.
    #
    # Wrapping the JSON-like Hash allows access with nice Ruby accessor methods
    # rather than using `obj["key"]` access.
    #
    # Wrappers also limit field visibility to fragment definitions.
    module QueryResult
      def self.part_of_definition?(definition, node)
        return true if definition == node
        result = false
        visitor = GraphQL::Language::Visitor.new(definition)
        visitor[GraphQL::Language::Nodes::Field] << ->(n, _parent) do
          result = true if n == node
        end
        visitor.visit
        result
      end

      def self.wrap(source_definition, irep_node, type, name: nil)
        if !part_of_definition?(source_definition.definition_node, irep_node.ast_node)
          return nil
        end

        case type
        when GraphQL::NonNullType
          wrap(source_definition, irep_node, type.of_type, name: name).to_non_null_type
        when GraphQL::ListType
          wrap(source_definition, irep_node, type.of_type, name: name).to_list_type
        when GraphQL::EnumType, GraphQL::ScalarType
          source_definition.types.const_get(type.name)
        when GraphQL::InterfaceType, GraphQL::UnionType
          type_module = source_definition.types.const_get(type.name)
          possible_types = []
          irep_node.typed_children.map { |child_type, fields|
            child_type_module = source_definition.types.const_get(child_type.name)
            possible_types << define(name: name, type_module: child_type_module, source_definition: source_definition, source_node: irep_node.ast_node, fields: fields.inject({}) { |h, (field_name, field_irep_node)|
              if klass = wrap(source_definition, field_irep_node, field_irep_node.definition.type, name: "#{name}[:#{field_name}]")
                h[field_name.to_sym] = klass
              end
              h
            })
          }
          type_module.new(possible_types)
        when GraphQL::ObjectType
          type_module = source_definition.types.const_get(type.name)
          fields = irep_node.typed_children[type]
          define(name: name, type_module: type_module, source_definition: source_definition, source_node: irep_node.ast_node, fields: fields.inject({}) { |h, (field_name, field_irep_node)|
            if klass = wrap(source_definition, field_irep_node, field_irep_node.definition.type, name: "#{name}[:#{field_name}]")
              h[field_name.to_sym] = klass
            end
            h
          })
        else
          raise TypeError, "unexpected #{type.class} for #{irep_node.inspect}"
        end
      end

      # Internal
      def self.define(name:, type_module:, source_definition:, source_node:, fields: {})
        Class.new(type_module) do
          extend QueryResult
          define_fields(fields)

          if source_definition.enforce_collocated_callers
            Client.enforce_collocated_callers(self, fields.keys, source_definition.source_location[0])
          end

          @name = name
          @source_definition = source_definition
          @source_node = source_node
        end
      end

      attr_reader :source_definition

      attr_reader :source_node

      def name
        @name || super || GraphQL::Client::QueryResult.name
      end

      # Internal
      def validate_cast!(obj)
        spreads = Set.new(self.spreads(obj.class.source_node).map(&:name))
        unless spreads.include?(source_node.name)
          raise TypeError, "#{self.source_definition.name} is not included in #{obj.class.source_definition.name}"
        end
      end

      # Internal
      def spreads(node)
        node.selections.flat_map do |selection|
          case selection
          when Language::Nodes::FragmentSpread
            selection
          when Language::Nodes::InlineFragment
            spreads(selection)
          else
            []
          end
        end
      end
    end
  end
end
