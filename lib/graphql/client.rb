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
      @definition_count = 0
    end

    class Definition < Module
      def initialize(client:, node:, name: nil)
        @client = client
        @node = node
        @name = name
      end

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
        @definition_name ||= name.gsub("::", "__")
      end

      attr_reader :node

      def document
        @document ||= Language::OperationSlice.slice(@client.document, @node.name).deep_freeze
      end

      def query_result_class
        @query_result_class ||= GraphQL::Client::QueryResult.wrap(node)
      end

      def new(*args)
        query_result_class.new(*args)
      end
    end

    def parse(str)
      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        fragment = ActiveSupport::Inflector.constantize($1)
        # TODO: Check type of fragment
        "...#{fragment.definition_name}"
      }

      doc = GraphQL::Relay::Parser.parse(str)

      mutator = GraphQL::Language::Mutator.new(doc)
      # TODO: Make this __typename injection optional
      mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

      aliases = {}
      doc.definitions.each do |definition|
        # XXX: Use constant name
        @definition_count += 1
        aliases[definition.name] = "D#{@definition_count}"
      end
      mutator.rename_definitions(aliases)

      nodes = doc.definitions.map(&:deep_freeze)
      self.document.definitions.concat(nodes)

      definitions = nodes.map { |node|
        Definition.new(client: self, node: node, name: node.name)
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
