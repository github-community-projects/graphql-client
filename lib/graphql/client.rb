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
