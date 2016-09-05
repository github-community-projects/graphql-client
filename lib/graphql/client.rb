require "active_support/inflector"
require "graphql"
require "graphql/client/const_proxy"
require "graphql/client/query_result"
require "graphql/language/mutator"
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
    end

    class Definition
      def initialize(name:, client:, source:)
        @name = name
        @client = client
        @source = source
      end

      def node
        return @node if defined? @node

        src = @source.strip
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
          definition.name = aliases[definition.name] = (@name.split("::") << definition.name).compact.join("__")
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
        Language::OperationSlice.slice(@client.document, operation_name).deep_freeze
      end

      def new(*args)
        GraphQL::Client::QueryResult.wrap(node.first).new(*args)
      end
    end

    def parse(str)
      definition = ConstProxy.new { |name| Definition.new(client: self, name: name, source: str) }
      @definitions << definition
      definition
    end

    def document
      GraphQL::Language::Nodes::Document.new(definitions: @definitions.flat_map(&:node)).deep_freeze
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
