require "active_support/inflector"
require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/document_definition_slice_ext"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/query_result_class_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "graphql/language/nodes/validate_ext"

module GraphQL
  class Client
    class << self
      attr_accessor :schema
    end

    def self.parse_document(str, schema: GraphQL::Client.schema)
      str = str.strip
      str, fragments = scan_interpolated_fragments(str)

      document = GraphQL.parse(str)
      document = document.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
      document.deep_freeze

      document.definitions.each do |definition|
        fragments[definition.name.to_sym] = definition if definition.is_a?(GraphQL::Language::Nodes::FragmentDefinition)
      end

      document = document.replace_fragment_spread(fragments)
      document.deep_freeze
      document.validate!(schema: schema) if schema

      defs = {}
      document.definitions.each do |definition|
        defs[definition.name.to_sym] = definition.query_result_class(shadow: fragments.values)
      end
      defs
    end

    def self.parse_query(str, **kargs)
      unless str.strip.start_with?("query")
        raise ArgumentError, "expected string to be a query:\n#{str}"
      end
      parse_document(str, **kargs).values.first
    end

    def self.parse_fragment(str, **kargs)
      unless str.strip.start_with?("fragment")
        raise ArgumentError, "expected string to be a fragment:\n#{str}"
      end
      str = str.strip.sub(/^fragment on /, "fragment __anonymous__ on ")
      parse_document(str, **kargs).values.first
    end

    def self.scan_interpolated_fragments(str)
      fragments = {}
      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        const_name = $1
        fragment_name = const_name.gsub(/::/, "__")
        fragments[fragment_name.to_sym] = ActiveSupport::Inflector.constantize(const_name).source_node
        "...#{fragment_name}"
      }
      return str, fragments
    end

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
        client.document.definition_slice(operation_name).deep_freeze
      end
    end

    def parse(str)
      client = self
      definition = Class.new do
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

    def validate!
      document.validate!(schema: @schema)
    end
  end
end
