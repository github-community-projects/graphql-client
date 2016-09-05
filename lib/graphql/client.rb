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
      @definition_count = 0
    end

    class Definition
      def initialize(client:, nodes:, query_result:)
        @client = client
        @_nodes = nodes
        @query_result = query_result
      end

      attr_reader :_nodes

      def operation_name
        if op = @_nodes.find { |d| d.is_a?(GraphQL::Language::Nodes::OperationDefinition) }
          op.name
        else
          nil
        end
      end

      def document
        @document ||= Language::OperationSlice.slice(@client.document, operation_name).deep_freeze
      end

      def new(*args)
        @query_result.new(*args)
      end
    end

    def parse(str)
      nodes = _parse(str)
      query_result = GraphQL::Client::QueryResult.wrap(nodes.first)
      definition = Definition.new(client: self, nodes: nodes, query_result: query_result)
      @definitions << definition
      definition
    end

    def _parse(str)
      str = str.strip

      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)(\.([a-zA-Z0-9_]+))?/) { |m|
        const_name, fragment_name = $1, $4
        nodes = ActiveSupport::Inflector.constantize(const_name)._nodes

        fragment_name = fragment_name ?
          nodes.find { |n| n.name.end_with?(fragment_name) }.name : # XXX
          nodes.first.name

        "...#{fragment_name}"
      }

      doc = GraphQL::Relay::Parser.parse(str)

      mutator = GraphQL::Language::Mutator.new(doc)

      aliases = {}
      doc.definitions.each do |definition|
        # XXX: Use constant name
        @definition_count += 1
        aliases[definition.name] = (["D#{@definition_count}"] << definition.name).compact.join("__")
      end
      mutator.rename_definitions(aliases)

      # TODO: Make this __typename injection optional
      mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

      doc.definitions.map(&:deep_freeze)
    end

    def document
      GraphQL::Language::Nodes::Document.new(definitions: @definitions.flat_map(&:_nodes)).deep_freeze
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
