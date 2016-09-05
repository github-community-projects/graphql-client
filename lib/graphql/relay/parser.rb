require "graphql"

module GraphQL
  module Relay
    module Parser
      ANONYMOUS_SENTINEL = "__anonymous__".freeze

      # Public: Extended GraphQL.parse that supports Relay style anonymous
      # fragments.
      #
      # TODO: See about getting support for this upstreamed to the graphql-ruby
      # gem.
      #
      # str - A GraphQL String
      #
      # Returns a GraphQL::Language::Nodes::Document.
      def self.parse(str)
        str = str.sub(/fragment on /, "fragment #{ANONYMOUS_SENTINEL} on ")
        document = GraphQL.parse(str)
        document.definitions.each do |node|
          node.name = nil if node.name == ANONYMOUS_SENTINEL
        end
        document
      end
    end
  end
end
