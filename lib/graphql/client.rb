require "active_support/inflector"
require "graphql"
require "graphql/client/query_result"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/operation_slice"

module GraphQL
  class Client
    class Error < StandardError; end
    class ValidationError < Error; end

    attr_reader :schema

    def initialize(schema:)
      @schema = schema
      @definitions = []
      @document = GraphQL::Language::Nodes::Document.new(definitions: @definitions)
    end

    class Definition < Module
      def self.for(node:, **kargs)
        case node
        when Language::Nodes::OperationDefinition
          OperationDefinition.new(node: node, **kargs)
        when Language::Nodes::FragmentDefinition
          FragmentDefinition.new(node: node, **kargs)
        else
          raise TypeError, "expected node to be a definition type, but was #{node.class}"
        end
      end

      def initialize(node:, document:)
        @definition_node = node
        @document = document
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

      # Public: Get document with only the definitions needed to perform this
      # operation.
      #
      # Returns GraphQL::Language::Nodes::Document with one OperationDefinition
      # and any FragmentDefinition dependencies.
      attr_reader :document

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
      definition_dependencies = Set.new

      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        const_name = $1
        case fragment = ActiveSupport::Inflector.safe_constantize(const_name)
        when FragmentDefinition
          definition_dependencies.merge(fragment.document.definitions)
          "...#{fragment.definition_name}"
        when nil
          raise NameError, "uninitialized constant #{const_name}\n#{str}"
        else
          raise TypeError, "expected #{const_name} to be a #{FragmentDefinition}, but was a #{fragment.class}"
        end
      }

      doc = GraphQL.parse(str)

      definition_dependencies.merge(doc.definitions)
      document_dependencies = Language::Nodes::Document.new(definitions: definition_dependencies.to_a)

      definitions, renames = {}, {}
      doc.definitions.each do |node|
        sliced_document = Language::OperationSlice.slice(document_dependencies, node.name)
        definition = Definition.for(node: node, document: sliced_document)
        renames[node.name] = -> { definition.definition_name }
        definitions[node.name] = definition
      end
      rename_definitions(doc, renames)

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

    def validate!
      validator = StaticValidation::Validator.new(schema: @schema)
      query = Query.new(@schema, document: document)

      validator.validate(query).fetch(:errors).each do |error|
        raise ValidationError, error["message"]
      end

      nil
    end

    private
      module LazyName
        def name
          @name.call
        end
      end

      def rename_definitions(document, definitions)
        rename_node = -> (node, parent) {
          if name = definitions[node.name]
            node.extend(LazyName) if name.is_a?(Proc)
            node.name = name
          end
        }

        visitor = Language::Visitor.new(document)
        visitor[Language::Nodes::FragmentDefinition].leave << rename_node
        visitor[Language::Nodes::OperationDefinition].leave << rename_node
        visitor[Language::Nodes::FragmentSpread].leave << rename_node
        visitor.visit

        nil
      end
  end
end
