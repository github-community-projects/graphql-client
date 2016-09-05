require "active_support/inflector"
require "graphql"
require "graphql/language/mutator"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/query_result_class_ext"
require "graphql/language/operation_slice"

module GraphQL
  class Client
    class Error < StandardError; end
    class ValidationError < Error; end

    attr_reader :schema

    def initialize(schema:)
      @schema = schema
      @definitions = []
    end

    module Definition
      def client
        @client
      end

      def source
        @source
      end

      def node
        return @node if defined? @node

        src = self.source.strip
        src = src.sub(/fragment on /, "fragment __anonymous__ on ")

        src = src.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)(\.([a-zA-Z0-9_]+))?/) { |m|
          const_name, fragment_name = $1, $4
          nodes = ActiveSupport::Inflector.constantize(const_name).node

          name = fragment_name ?
            nodes.find { |n| n.name.end_with?(fragment_name) }.name :
            nodes.first.name

          "...#{name}"
        }

        doc = GraphQL.parse(src)

        aliases = {}

        doc.definitions.each do |definition|
          definition.name = nil if definition.name == "__anonymous__"
          definition.name = aliases[definition.name] = (self.name.split("::") << definition.name).compact.join("__")
        end

        visitor = GraphQL::Language::Visitor.new(doc)
        visitor[GraphQL::Language::Nodes::FragmentSpread] << -> (node, parent) {
          node.name = aliases.fetch(node.name, node.name)
        }
        visitor.visit

        # TODO: Make this __typename injection optional
        mutator = GraphQL::Language::Mutator.new(doc)
        mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

        @node = doc.definitions.map(&:deep_freeze)
      end

      def operation_name
        if op = node.find { |d| d.is_a?(GraphQL::Language::Nodes::OperationDefinition) }
          op.name
        else
          nil
        end
      end

      def document
        Language::OperationSlice.slice(client.document, operation_name).deep_freeze
      end

      def new(*args)
        fragments = client.fragments
        node.first.query_result_class(fragments: fragments, shadow: Set.new(fragments.values)).new(*args)
      end
    end

    def parse(str)
      client = self
      definition = Module.new do
        extend Definition
        @client = client
        @source = str
      end
      @definitions << definition
      definition
    end

    def document
      GraphQL::Language::Nodes::Document.new(definitions: @definitions.flat_map(&:node)).deep_freeze
    end

    def fragments
      Hash[document.definitions.select { |definition|
        definition.is_a?(GraphQL::Language::Nodes::FragmentDefinition)
      }.map { |fragment|
        [fragment.name.to_sym, fragment]
      }]
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
