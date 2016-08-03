require "graphql"
require "graphql/language/nodes/query_result_class_ext"
require "minitest/autorun"

class TestQueryResultClassExt < MiniTest::Test
  def test_query_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        version
      }
    GRAPHQL

    assert query = document.definitions.first
    assert query_klass = query.query_result_class

    assert data = query_klass.new({"version" => 42})
    assert_equal 42, data.version
  end

  def test_empty_query_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
      }
    GRAPHQL

    assert query = document.definitions.first
    assert query_klass = query.query_result_class

    assert query_klass.new({})
  end

  def test_field_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          id
          name
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = users_field.query_result_class

    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_aliased_field_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          relayID: id
          fullName: name
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = users_field.query_result_class

    assert user = user_klass.new({"relayID" => 1, "fullName" => "Joshua Peek"})
    assert_equal 1, user.relay_id
    assert_equal "Joshua Peek", user.full_name
  end

  def test_empty_field_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        version
      }
    GRAPHQL

    assert query = document.definitions.first
    assert version_field = query.selections.first
    refute version_field.query_result_class
  end

  def test_fragment_definition_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert viewer_fragment = document.definitions.first
    assert viewer_klass = viewer_fragment.query_result_class

    assert viewer = viewer_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, viewer.id
    assert_equal "Josh", viewer.name
  end

  def test_empty_fragment_definition_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Viewer on User {
      }
    GRAPHQL

    assert viewer_fragment = document.definitions.first
    assert viewer_klass = viewer_fragment.query_result_class

    assert viewer_klass.new({})
  end

  def test_inline_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ... on User {
            id
            name
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_fragment = user_field.selections.first
    assert user_klass = user_fragment.query_result_class

    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_empty_inline_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ... on User {
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_fragment = user_field.selections.first
    assert user_klass = user_fragment.query_result_class

    assert user_klass.new({})
  end

  def test_spread_fragment_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          ...Viewer
        }
      }

      fragment Viewer on User {
        id
        name
      }
    GRAPHQL

    assert query = document.definitions.first
    assert fragment = document.definitions.last
    assert user_field = query.selections.first
    assert user_klass = user_field.query_result_class(fragments: {:Viewer => fragment})

    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end
end
