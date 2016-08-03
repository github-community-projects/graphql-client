require "graphql"
require "graphql/language/nodes/query_result_class_ext"
require "minitest/autorun"

class TestQueryResultClassExt < MiniTest::Test
  def test_fragment_definition_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert viewer_fragment = document.definitions.first
    assert viewer_klass = viewer_fragment.query_result_class

    viewer = viewer_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, viewer.id
    assert_equal "Josh", viewer.name
  end
end
