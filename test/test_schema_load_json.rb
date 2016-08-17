require "graphql"
require "graphql/schema_load_json"
require "minitest/autorun"

class TestSchemaLoadJSON < MiniTest::Test
  JSON_PATH = File.expand_path("../swapi-schema.json", __FILE__)

  def test_schema_load_json
    assert schema = GraphQL::Schema.load_json(File.read(JSON_PATH))

    assert_equal "Root", schema.query.name
    assert root_fields = schema.types["Root"].fields

    assert_equal schema.types["FilmsConnection"], root_fields["allFilms"].type
    assert_equal ["after", "first", "before", "last"], root_fields["allFilms"].arguments.keys

    assert_equal schema.types["Film"], root_fields["film"].type
    assert_equal ["id", "filmID"], root_fields["film"].arguments.keys

    assert_equal schema.types["Node"], root_fields["node"].type
    assert_equal ["id"], root_fields["node"].arguments.keys
  end
end
