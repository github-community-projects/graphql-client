# frozen_string_literal: true

require "graphql/client/schema/object_type"

module GraphQL
  class Client
    # Definitions are constructed by Client.parse and wrap a parsed AST of the
    # query string as well as hold references to any external query definition
    # dependencies.
    #
    # Definitions MUST be assigned to a constant.
    class Definition < Module
      def self.for(irep_node:, **kargs)
        case irep_node.ast_node
        when Language::Nodes::OperationDefinition
          OperationDefinition.new(irep_node: irep_node, **kargs)
        when Language::Nodes::FragmentDefinition
          FragmentDefinition.new(irep_node: irep_node, **kargs)
        else
          raise TypeError, "expected node to be a definition type, but was #{irep_node.ast_node.class}"
        end
      end

      def initialize(irep_node:, document:, types:, source_location:, enforce_collocated_callers:)
        @definition_irep_node = irep_node
        @document = document
        @types = types
        @source_location = source_location
        @enforce_collocated_callers = enforce_collocated_callers
      end

      # Internal: Get underlying operation or fragment defintion AST node for
      # definition.
      #
      # Returns OperationDefinition or FragmentDefinition object.
      def definition_node
        definition_irep_node.ast_node
      end

      # Internal: Get underlying IRep Node for the definition.
      #
      # Returns GraphQL::InternalRepresentation::Node object.
      attr_reader :definition_irep_node

      # Public: Global name of definition in client document.
      #
      # Returns a GraphQL safe name of the Ruby constant String.
      #
      #   "Users::UserQuery" #=> "Users__UserQuery"
      #
      # Returns String.
      def definition_name
        return @definition_name if defined?(@definition_name)

        if name
          @definition_name = name.gsub("::", "__").freeze
        else
          "#{self.class.name}_#{object_id}".gsub("::", "__").freeze
        end
      end

      # Public: Get document with only the definitions needed to perform this
      # operation.
      #
      # Returns GraphQL::Language::Nodes::Document with one OperationDefinition
      # and any FragmentDefinition dependencies.
      attr_reader :document

      attr_reader :types

      # Public: Returns the Ruby source filename and line number containing this
      # definition was not defined in Ruby.
      #
      # Returns Array pair of [String, Fixnum].
      attr_reader :source_location

      attr_reader :enforce_collocated_callers

      def new(obj, errors = Errors.new)
        case type
        when GraphQL::Client::Schema::PossibleTypes
          type.cast(obj.to_h, obj.errors)
        when GraphQL::Client::Schema::ObjectType
          case obj
          when NilClass, type
            obj
          when Hash
            type.new(obj, errors)
          else
            type.validate_cast!(obj)
            type.cast(obj.to_h, obj.errors)
          end
        else
          raise TypeError, "unexpected #{type.class}"
        end
      end

      def type
        # TODO: Fix type indirection
        @type ||= GraphQL::Client::QueryResult.wrap(self, definition_irep_node, definition_irep_node.return_type, name: "#{name}.type")
      end
    end
  end
end
