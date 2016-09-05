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
    assert_equal query, query_klass.source_node

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
    assert_equal query, query_klass.source_node

    assert query_klass.new({})
  end

  def test_shadowed_query_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        version
      }
    GRAPHQL

    assert query = document.definitions.first
    assert query_klass = query.query_result_class(shadow: Set.new(query.selections))
    assert_equal query, query_klass.source_node

    assert data = query_klass.new({"version" => 42})
    refute data.respond_to?(:version)
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
    assert_equal users_field, user_klass.source_node

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
    assert_equal users_field, user_klass.source_node

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

  def test_merge_nested_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        users {
          id
          name

          issues {
            count
            assignedCount
          }

          issues {
            count
            authoredCount
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert users_field = query.selections.first
    assert user_klass = users_field.query_result_class
    assert_equal users_field, user_klass.source_node

    assert user = user_klass.new({"id" => 1, "name" => "Josh", "issues" => { "count" => 3, "assignedCount" => 2, "authoredCount" => 1 } })
    assert_equal 1, user.id
    assert_equal "Josh", user.name
    assert_equal 3, user.issues.count
    assert_equal 2, user.issues.assigned_count
    assert_equal 1, user.issues.authored_count
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
    assert_equal viewer_fragment, viewer_klass.source_node

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
    assert_equal viewer_fragment, viewer_klass.source_node

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

    assert user_klass = user_field.query_result_class
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name

    assert user_klass = user_fragment.query_result_class
    assert_equal user_fragment, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_shadowed_inline_fragment_query_result_class
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
    assert user_klass = user_field.query_result_class(shadow: Set.new([user_fragment]))
    assert_equal user_field, user_klass.source_node

    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)
  end

  def test_shadowed_inline_fragment_with_overlapping_fields_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          id
          login
          ... on User {
            id
            name
          }
        }
      }
    GRAPHQL

    assert query = document.definitions.first
    assert user_field = query.selections.first
    assert user_fragment = user_field.selections[2]
    assert user_klass = user_field.query_result_class(shadow: Set.new([user_fragment]))
    assert_equal user_field, user_klass.source_node

    assert user = user_klass.new({"id" => 1, "login" => "josh", "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)
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
    assert_equal user_fragment, user_klass.source_node

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
    assert_equal user_field, user_klass.source_node

    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "Josh", user.name
  end

  def test_shadowed_spread_fragment_query_result_class
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

    assert user_klass = user_field.query_result_class(shadow: Set.new(user_field.selections))
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)

    assert user_klass = user_field.query_result_class(fragments: {:Viewer => fragment}, shadow: Set.new([fragment]))
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "name" => "Josh"})
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)
  end

  def test_shadowed_spread_fragment_overlapping_fields_query_result_class
    document = GraphQL.parse(<<-'GRAPHQL')
      query {
        user {
          id
          ...Viewer
          login
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

    assert user_klass = user_field.query_result_class(shadow: Set.new([user_field.selections[1]]))
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "login" => "josh", "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)

    assert user_klass = user_field.query_result_class(fragments: {:Viewer => fragment}, shadow: Set.new([fragment]))
    assert_equal user_field, user_klass.source_node
    assert user = user_klass.new({"id" => 1, "login" => "josh", "name" => "Josh"})
    assert_equal 1, user.id
    assert_equal "josh", user.login
    refute user.respond_to?(:name)
  end

  def test_query_result_class_inline_fragment_casting
    skip

    document = GraphQL.parse(<<-'GRAPHQL')
      fragment Foo on Node {
        __typename
        id

        ... on User {
          fullName
        }
      }

      fragment Bar on Node {
        ... on Company {
          name
        }
      }
    GRAPHQL

    assert node_fragment = document.definitions.first
    assert node_klass = node_fragment.query_result_class
    assert_equal node_fragment, node_klass.source_node

    assert user_fragment = document.definitions[0].selections[2]
    assert_equal "User", user_fragment.type

    assert company_fragment = document.definitions[1].selections[0]
    assert_equal "Company", company_fragment.type

    assert node_user = node_klass.new({
      "__typename" => "User",
      "id" => 1,
      "fullName" => "Joshua Peek"
    })
    assert_equal 1, node_user.id
    assert_equal "Joshua Peek", node_user.full_name

    assert user = user_fragment.query_result_class.cast(node_user)
    assert_equal "Joshua Peek", user.full_name
    refute user.respond_to?(:id)
    refute user.respond_to?(:name)

    assert_raises TypeError do
      company_fragment.query_result_class.cast(node_user)
    end
  end

  def test_relay_connection_enumerator
    query = GraphQL.parse(<<-'GRAPHQL').definitions.first
      query MoreRebelShipsQuery {
        rebels {
          name,
          ships(first: 2) {
            edges {
              cursor
              node {
                name
              }
            }
          }
        }
      }
    GRAPHQL

    assert query_klass = query.query_result_class
    data = query_klass.new({
      "rebels" => {
        "name" => "Alliance to Restore the Republic",
        "ships" => {
          "edges" => [
            {
              "cursor" => "YXJyYXljb25uZWN0aW9uOjA=",
              "node" => {
                "name" => "X-Wing"
              }
            },
            {
              "cursor" => "YXJyYXljb25uZWN0aW9uOjE=",
              "node" => {
                "name" => "Y-Wing"
              }
            }
          ]
        }
      }
    })

    assert_equal "Alliance to Restore the Republic", data.rebels.name
    assert_equal 2, data.rebels.ships.edges.length
    assert_equal "X-Wing", data.rebels.ships.edges[0].node.name
    assert_equal "Y-Wing", data.rebels.ships.edges[1].node.name

    assert_equal ["X-Wing", "Y-Wing"],
      data.rebels.ships.each_node.map { |ship| ship.name }
  end
end
