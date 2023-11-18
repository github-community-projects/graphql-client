# frozen_string_literal: true
module GraphQL
  class Client
    module TypeStack
      # @return [GraphQL::Schema] the schema whose types are present in this document
      attr_reader :schema

      # When it enters an object (starting with query or mutation root), it's pushed on this stack.
      # When it exits, it's popped off.
      # @return [Array<GraphQL::ObjectType, GraphQL::Union, GraphQL::Interface>]
      attr_reader :object_types

      # When it enters a field, it's pushed on this stack (useful for nested fields, args).
      # When it exits, it's popped off.
      # @return [Array<GraphQL::Field>] fields which have been entered
      attr_reader :field_definitions

      # Directives are pushed on, then popped off while traversing the tree
      # @return [Array<GraphQL::Node::Directive>] directives which have been entered
      attr_reader :directive_definitions

      # @return [Array<GraphQL::Node::Argument>] arguments which have been entered
      attr_reader :argument_definitions

      # @return [Array<String>] fields which have been entered (by their AST name)
      attr_reader :path

      # @param schema [GraphQL::Schema] the schema whose types to use when climbing this document
      # @param visitor [GraphQL::Language::Visitor] a visitor to follow & watch the types
      def initialize(document, schema:, **rest)
        @schema = schema
        @object_types = []
        @field_definitions = []
        @directive_definitions = []
        @argument_definitions = []
        @path = []
        super(document, **rest)
      end

      def on_directive(node, parent)
        directive_defn = @schema.directives[node.name]
        @directive_definitions.push(directive_defn)
        super(node, parent)
      ensure
        @directive_definitions.pop
      end

      def on_field(node, parent)
        parent_type = @object_types.last
        parent_type = parent_type.unwrap

        field_definition = @schema.get_field(parent_type, node.name)
        @field_definitions.push(field_definition)
        if !field_definition.nil?
          next_object_type = field_definition.type
          @object_types.push(next_object_type)
        else
          @object_types.push(nil)
        end
        @path.push(node.alias || node.name)
        super(node, parent)
      ensure
        @field_definitions.pop
        @object_types.pop
        @path.pop
      end

      def on_argument(node, parent)
        if @argument_definitions.last
          arg_type = @argument_definitions.last.type.unwrap
          if arg_type.kind.input_object?
            argument_defn = arg_type.arguments[node.name]
          else
            argument_defn = nil
          end
        elsif @directive_definitions.last
          argument_defn = @directive_definitions.last.arguments[node.name]
        elsif @field_definitions.last
          argument_defn = @field_definitions.last.arguments[node.name]
        else
          argument_defn = nil
        end
        @argument_definitions.push(argument_defn)
        @path.push(node.name)
        super(node, parent)
      ensure
        @argument_definitions.pop
        @path.pop
      end

      def on_operation_definition(node, parent)
        # eg, QueryType, MutationType
        object_type = @schema.root_type_for_operation(node.operation_type)
        @object_types.push(object_type)
        @path.push("#{node.operation_type}#{node.name ? " #{node.name}" : ""}")
        super(node, parent)
      ensure
        @object_types.pop
        @path.pop
      end

      def on_inline_fragment(node, parent)
        object_type = if node.type
                        @schema.get_type(node.type.name)
                      else
                        @object_types.last
                      end
        if !object_type.nil?
          object_type = object_type.unwrap
        end
        @object_types.push(object_type)
        @path.push("...#{node.type ? " on #{node.type.to_query_string}" : ""}")
        super(node, parent)
      ensure
        @object_types.pop
        @path.pop
      end

      def on_fragment_definition(node, parent)
        object_type = if node.type
                        @schema.get_type(node.type.name)
                      else
                        @object_types.last
                      end
        if !object_type.nil?
          object_type = object_type.unwrap
        end
        @object_types.push(object_type)
        @path.push("fragment #{node.name}")
        super(node, parent)
      ensure
        @object_types.pop
        @path.pop
      end

      def on_fragment_spread(node, parent)
        @path.push("... #{node.name}")
        super(node, parent)
      ensure
        @path.pop
      end
    end
  end
end
