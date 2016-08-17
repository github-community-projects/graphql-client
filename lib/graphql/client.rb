require "graphql"
require "graphql/client/document"
require "graphql/client/fragment"
require "graphql/client/node"
require "graphql/client/query_result"
require "graphql/client/query"

module GraphQL
  module Client
    class << self
      attr_accessor :schema
    end
  end
end
