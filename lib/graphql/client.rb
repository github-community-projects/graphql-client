require "active_support/inflector"
require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/fragment_ext"
require "graphql/language/nodes/inject_selection_ext"
require "graphql/language/nodes/query_result_class_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "graphql/language/nodes/validate_ext"

module GraphQL
  module Client
    class << self
      attr_accessor :schema
    end

    def self.parse_document(str, schema: GraphQL::Client.schema)
      str = str.strip
      str, fragments = scan_interpolated_fragments(str)

      document = GraphQL.parse(str)
      document = document.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))

      document.definitions.each do |definition|
        fragments[definition.name.to_sym] = definition if definition.is_a?(GraphQL::Language::Nodes::FragmentDefinition)
      end

      document = document.replace_fragment_spread(fragments)

      document.definitions.inject({}) do |doc, definition|
        name = definition.name.to_sym

        case definition
        when GraphQL::Language::Nodes::OperationDefinition
          query = definition.deep_freeze.query_result_class(shadow: fragments.values)
          query.node.validate!(schema: schema) if schema
          doc[name] = query

        when GraphQL::Language::Nodes::FragmentDefinition
          definition = definition.to_inline_fragment
          fragment = definition.deep_freeze.query_result_class(shadow: fragments.values)
          fragment.node.validate!(schema: schema) if schema
          doc[name] = fragment
        end

        doc
      end
    end

    def self.parse_query(str, schema: GraphQL::Client.schema)
      str = str.strip
      str, fragments = scan_interpolated_fragments(str)

      if str.start_with?("query")
        doc = GraphQL.parse(str)
        doc = doc.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
        doc = doc.replace_fragment_spread(fragments)
        node = doc.definitions.first
      else
        raise ArgumentError, "expected string to be a query:\n#{str}"
      end

      query = node.deep_freeze.query_result_class(shadow: fragments.values)
      query.node.validate!(schema: schema) if schema
      query
    end

    def self.parse_fragment(str, schema: GraphQL::Client.schema)
      str = str.strip
      str, fragments = scan_interpolated_fragments(str)

      if str.start_with?("fragment")
        str = str.sub(/^fragment on /, "fragment __anonymous__ on ")
        doc = GraphQL.parse(str)
        doc = doc.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
        doc = doc.replace_fragment_spread(fragments)
        fragment = doc.definitions.first
        node = fragment.to_inline_fragment
      else
        raise ArgumentError, "expected string to be a fragment:\n#{str}"
      end

      fragment = node.deep_freeze.query_result_class(shadow: fragments.values)
      fragment.node.validate!(schema: schema) if schema
      fragment
    end

    def self.scan_interpolated_fragments(str)
      fragments, index = {}, 1
      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        index += 1
        name = "__fragment#{index}__"
        fragments[name.to_sym] = ActiveSupport::Inflector.constantize($1).source_node
        "...#{name}"
      }
      return str, fragments
    end
  end
end
