# frozen_string_literal: true

require "graphql"
require "graphql/client/collocated_enforcement"
require "graphql/client/schema/object_type"
require "graphql/client/schema/possible_types"
require "set"

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

      def initialize(client:, document:, irep_node:, source_location:)
        @client = client
        @document = document
        @definition_irep_node = irep_node
        @source_location = source_location
        @schema_class = define_class(definition_irep_node, definition_irep_node.return_type)
      end

      # Internal: Get associated owner GraphQL::Client instance.
      attr_reader :client

      # Internal root schema class for defintion. Returns
      # GraphQL::Client::Schema::ObjectType or
      # GraphQL::Client::Schema::PossibleTypes.
      attr_reader :schema_class

      # Deprecated: Use schema_class
      alias_method :type, :schema_class

      # Internal: Get underlying IRep Node for the definition.
      #
      # Returns GraphQL::InternalRepresentation::Node object.
      attr_reader :definition_irep_node

      # Internal: Get underlying operation or fragment defintion AST node for
      # definition.
      #
      # Returns OperationDefinition or FragmentDefinition object.
      def definition_node
        definition_irep_node.ast_node
      end

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

      # Public: Returns the Ruby source filename and line number containing this
      # definition was not defined in Ruby.
      #
      # Returns Array pair of [String, Fixnum].
      attr_reader :source_location

      def new(obj, errors = Errors.new)
        case schema_class
        when GraphQL::Client::Schema::PossibleTypes
          case obj
          when NilClass
            nil
          else
            schema_class.cast(obj.to_h, obj.errors)
          end
        when GraphQL::Client::Schema::ObjectType
          case obj
          when NilClass, schema_class
            obj
          when Hash
            schema_class.new(obj, errors)
          else
            if obj.class.is_a?(GraphQL::Client::Schema::ObjectType)
              unless obj.class._spreads.include?(definition_node.name)
                raise TypeError, "#{definition_node.name} is not included in #{obj.class.source_definition.name}"
              end
              schema_class.cast(obj.to_h, obj.errors)
            else
              raise TypeError, "unexpected #{obj.class}"
            end
          end
        else
          raise TypeError, "unexpected #{schema_class}"
        end
      end

      # Internal: Nodes AST indexes.
      def indexes
        @indexes ||= begin
          visitor = GraphQL::Language::Visitor.new(document)
          definitions = index_node_definitions(visitor)
          spreads = index_spreads(visitor)
          visitor.visit
          { definitions: definitions, spreads: spreads }
        end
      end

      private
        def define_class(irep_node, type)
          case type
          when GraphQL::NonNullType
            klass = define_class(irep_node, type.of_type)

            # Skip non-nullable wrapper if field includes a @include or @skip directive
            directives = irep_node.ast_node.directives.map(&:name)
            return klass if directives.include?("include") || directives.include?("skip")

            klass.to_non_null_type
          when GraphQL::ListType
            define_class(irep_node, type.of_type).to_list_type
          when GraphQL::EnumType, GraphQL::ScalarType
            client.types.const_get(type.name)
          when GraphQL::InterfaceType, GraphQL::UnionType
            possible_types = irep_node.typed_children.map { |ctype, fields|
              define_object_class(irep_node, ctype, fields)
            }
            client.types.const_get(type.name).new(possible_types)
          when GraphQL::ObjectType
            define_object_class(irep_node, type, irep_node.typed_children[type])
          else
            raise TypeError, "unexpected #{type.class} for #{irep_node.inspect}"
          end
        end

        def define_object_class(irep_node, type, fields)
          type_module = client.types.const_get(type.name)

          fields = fields.inject({}) { |h, (field_name, field_irep_node)|
            if indexes[:definitions][field_irep_node.ast_node] == definition_node
              h[field_name.to_sym] = define_class(field_irep_node, field_irep_node.definition.type)
            end
            h
          }

          source_definition = self

          Class.new(type_module) do
            define_fields(fields)

            if source_definition.client.enforce_collocated_callers
              Client.enforce_collocated_callers(self, fields.keys, source_definition.source_location[0])
            end

            class << self
              attr_reader :source_definition
              attr_reader :_spreads
            end

            @source_definition = source_definition
            @_spreads = source_definition.indexes[:spreads][irep_node.ast_node]
          end
        end

        def index_spreads(visitor)
          spreads = {}
          on_node = ->(node, _parent) { spreads[node] = Set.new(flatten_spreads(node).map(&:name)) }

          visitor[GraphQL::Language::Nodes::Field] << on_node
          visitor[GraphQL::Language::Nodes::FragmentDefinition] << on_node
          visitor[GraphQL::Language::Nodes::OperationDefinition] << on_node

          spreads
        end

        def flatten_spreads(node)
          node.selections.flat_map do |selection|
            case selection
            when Language::Nodes::FragmentSpread
              selection
            when Language::Nodes::InlineFragment
              flatten_spreads(selection)
            else
              []
            end
          end
        end

        def index_node_definitions(visitor)
          current_definition = nil
          enter_definition = ->(node, _parent) { current_definition = node }
          leave_definition = ->(node, _parent) { current_definition = nil }

          visitor[GraphQL::Language::Nodes::FragmentDefinition].enter << enter_definition
          visitor[GraphQL::Language::Nodes::FragmentDefinition].leave << leave_definition
          visitor[GraphQL::Language::Nodes::OperationDefinition].enter << enter_definition
          visitor[GraphQL::Language::Nodes::OperationDefinition].leave << leave_definition

          definitions = {}
          on_node = ->(node, _parent) { definitions[node] = current_definition }
          visitor[GraphQL::Language::Nodes::Field] << on_node
          visitor[GraphQL::Language::Nodes::FragmentDefinition] << on_node
          visitor[GraphQL::Language::Nodes::InlineFragment] << on_node
          visitor[GraphQL::Language::Nodes::OperationDefinition] << on_node
          definitions
        end
    end
  end
end
