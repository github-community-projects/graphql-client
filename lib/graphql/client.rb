require "active_support/inflector"
require "graphql"
require "graphql/client/query_result"
require "graphql/language/mutator"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/operation_slice"
require "graphql/relay/parser"

module GraphQL
  class Client
    class Error < StandardError; end
    class ValidationError < Error; end

    attr_reader :schema

    def initialize(schema:)
      @schema = schema
      @definitions = []
      @document = GraphQL::Language::Nodes::Document.new(definitions: @definitions)
      @document_slices = {}
    end

    class Definition < Module
      def initialize(node:)
        @definition_node = node
      end

      # Internal: Get underlying operation or fragment defintion AST node for
      # definition.
      #
      # Returns OperationDefinition or FragmentDefinition object.
      attr_reader :definition_node

      # Public: Ruby constant name of definition.
      #
      # Returns String or errors if definition was not assigned to a constant.
      def name
        @name ||= super || raise(RuntimeError, "definition must be assigned to a constant")
      end

      # Public: Global name of definition in client document.
      #
      # Returns a GraphQL safe name of the Ruby constant String.
      #
      #   "Users::UserQuery" #=> "Users__UserQuery"
      #
      # Returns String.
      def definition_name
        @definition_name ||= name.gsub("::", "__").freeze
      end

      def new(*args)
        query_result_class.new(*args)
      end

      private
        def query_result_class
          @query_result_class ||= GraphQL::Client::QueryResult.wrap(definition_node, name: name)
        end
    end

    class OperationDefinition < Definition
      # Public: Alias for definition name.
      alias_method :operation_name, :definition_name
    end

    class FragmentDefinition < Definition
    end

    def parse(str)
      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        const_name = $1
        case fragment = ActiveSupport::Inflector.safe_constantize(const_name)
        when FragmentDefinition
          "...#{fragment.definition_name}"
        when nil
          raise NameError, "uninitialized constant #{const_name}\n#{str}"
        else
          raise TypeError, "expected #{const_name} to be a #{FragmentDefinition}, but was a #{fragment.class}"
        end
      }

      doc = GraphQL::Relay::Parser.parse(str)

      mutator = GraphQL::Language::Mutator.new(doc)

      # TODO: Make this __typename injection optional
      mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

      definitions, renames = {}, {}
      doc.definitions.each do |node|
        local_name = node.name
        definition = case node
        when Language::Nodes::OperationDefinition
          OperationDefinition.new(node: node)
        when Language::Nodes::FragmentDefinition
          FragmentDefinition.new(node: node)
        end
        definitions[local_name] = definition
        renames[local_name] = -> { definition.definition_name }
      end
      mutator.rename_definitions(renames)

      doc.deep_freeze

      self.document.definitions.concat(doc.definitions)

      if definitions[nil]
        definitions[nil]
      else
        Module.new do
          definitions.each do |name, definition|
            const_set(name, definition)
          end
        end
      end
    end

    def document
      @document
    end

    def document_slice(operation_name)
      @document_slices[operation_name] ||= Language::OperationSlice.slice(document, operation_name).deep_freeze
    end

    def validate!
      validator = StaticValidation::Validator.new(schema: @schema)
      query = Query.new(@schema, document: document)

      validator.validate(query).fetch(:errors).each do |error|
        raise ValidationError, error["message"]
      end

      nil
    end
  end
end
