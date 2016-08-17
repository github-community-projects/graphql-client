require "graphql"
require "graphql/schema/json_loader"

module GraphQL
  class Schema
    def self.load_json(json)
      Schema::JSONLoader.define_schema(json)
    end
  end
end
