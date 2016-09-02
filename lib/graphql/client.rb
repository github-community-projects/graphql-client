require "active_support/inflector"
require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/query_result_class_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "graphql/language/nodes/validate_ext"

module GraphQL
  module Client
    class << self
      attr_accessor :schema
    end

    def self.parse(str)
      str = str.strip
      str, fragments = scan_interpolated_fragments(str)

      document = GraphQL.parse(str)

      fragments.each do |name, node|
        document.definitions << GraphQL::Language::Nodes::FragmentDefinition.new(name: name.to_s, type: node.type, directives: node.directives, selections: node.selections)
      end

      document
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
  end
end
