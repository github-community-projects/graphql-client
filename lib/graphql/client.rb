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
      @document = GraphQL::Language::Nodes::Document.new(definitions: [])
      @definition_count = 0
    end

    class Definition < Module
      def initialize(client:, node:, query_result:)
        @client = client
        @node = node
        @query_result = query_result
        @document = Language::OperationSlice.slice(@client.document, @node.name).deep_freeze
      end

      attr_reader :node, :document

      def new(*args)
        @query_result.new(*args)
      end
    end

    def parse(str)
      str = str.strip

      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        const_name = $1
        node = ActiveSupport::Inflector.constantize(const_name).node
        fragment_name = node.name
        "...#{fragment_name}"
      }

      doc = GraphQL::Relay::Parser.parse(str)

      mutator = GraphQL::Language::Mutator.new(doc)

      aliases = {}
      doc.definitions.each do |definition|
        # XXX: Use constant name
        @definition_count += 1
        aliases[definition.name] = "D#{@definition_count}"
      end
      mutator.rename_definitions(aliases)

      # TODO: Make this __typename injection optional
      mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

      nodes = doc.definitions.map(&:deep_freeze)
      self.document.definitions.concat(nodes)

      definitions = nodes.map { |node|
        query_result = GraphQL::Client::QueryResult.wrap(node)
        Definition.new(client: self, node: node, query_result: query_result)
      }

      if aliases[nil]
        definitions.first
      else
        m = Module.new
        definitions.each do |definition|
          m.const_set(aliases.key(definition.node.name), definition)
        end
        m
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
  end
end
