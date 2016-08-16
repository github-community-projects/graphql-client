require "graphql"
require "graphql/client/node"

module GraphQL
  module Client
    class Query < Node
      def document
        GraphQL::Language::Nodes::Document.new(definitions: [node])
      end
    end
  end
end
