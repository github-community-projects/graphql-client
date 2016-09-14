require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClientSchema < MiniTest::Test
  QueryType = GraphQL::ObjectType.define do
    name "AwesomeQuery"
    field :version, !types.Int
  end

  Schema = GraphQL::Schema.define(query: QueryType)

  def test_load_schema_identity
    schema = GraphQL::Client.load_schema(Schema)
    assert_equal "AwesomeQuery", schema.query.name
  end

  def test_load_schema_from_introspection_query_result
    result = Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY)
    schema = GraphQL::Client.load_schema(result)
    assert_equal "AwesomeQuery", schema.query.name
  end

  def test_load_schema_from_json_string
    json = JSON.generate(Schema.execute(GraphQL::Introspection::INTROSPECTION_QUERY))
    schema = GraphQL::Client.load_schema(json)
    assert_equal "AwesomeQuery", schema.query.name
  end
end
