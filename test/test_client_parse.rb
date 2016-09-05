require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientParse < MiniTest::Test
  def test_parse_fragment
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    assert_equal "User", fragment.node.type
    assert_equal "login", fragment.node.selections[1].name
  end

  def test_parse_query
    query = GraphQL::Client::Query.parse(<<-'GRAPHQL')
      query UserQuery {
        viewer {
          login
        }
      }
    GRAPHQL

    assert_equal "query", query.node.operation_type
    assert_equal "UserQuery", query.node.name
    assert_equal "viewer", query.node.selections[1].name
    assert_equal "login", query.node.selections[1].selections[1].name
  end

  def test_parse_document
    document = GraphQL::Client::Document.parse(<<-'GRAPHQL')
      query UserQuery {
        viewer {
          ...UserFragment
        }
      }

      fragment UserFragment on User {
        login
      }

      fragment RepositoryFragment on Repository {
        name
      }
    GRAPHQL

    assert_equal "viewer", document[:UserQuery].node.selections[1].name
    assert_equal "login", document[:UserFragment].node.selections[1].name
    assert_equal "name", document[:RepositoryFragment].node.selections[1].name
  end

  def test_parse_query_wrong_type
    assert_raises ArgumentError do
      GraphQL::Client::Query.parse(<<-'GRAPHQL')
        fragment on User {
          login
        }
      GRAPHQL
    end
  end

  def test_parse_fragment_wrong_type
    assert_raises ArgumentError do
      GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
        query UserQuery {
          viewer {
            login
          }
        }
      GRAPHQL
    end
  end

  def test_fragment_query_result_with_one_field
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    user = fragment.new({"__typename" => "User", "login" => "josh"})
    assert_equal "josh", user.login
  end

  def test_fragment_query_result_with_multiple_field
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        id
        login
        email
      }
    GRAPHQL

    user = fragment.new({"id" => "1", "login" => "josh", "email" => "josh@github.com"})
    assert_equal "josh", user.login
  end

  def test_fragment_query_result_case_aliases
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        login_url
        profileName
        isCool
      }
    GRAPHQL

    user = fragment.new({"__typename" => "User", "login_url" => "/login", "profileName" => "Josh", "isCool" => true})
    assert_equal "/login", user.login_url
    assert_equal "Josh", user.profile_name
    assert user.is_cool?
  end

  def test_fragment_field_alias
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        name: profileName
      }
    GRAPHQL

    user = fragment.new({"name" => "Josh"})
    assert_equal "Josh", user.name
  end

  def test_fragment_query_result_with_nested_fields
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on User {
        id
        repositories {
          name
          watchers {
            login
          }
        }
      }
    GRAPHQL

    user = fragment.new({
      "id" => "1",
      "repositories" => [
        {
          "name" => "github",
          "watchers" => {
            "login" => "josh"
          }
        }
      ]
    })

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers.login
  end

  def test_query_result_with_nested_fields
    query = GraphQL::Client::Query.parse(<<-'GRAPHQL')
      query UserQuery {
        id
        repositories {
          name
          watchers {
            login
          }
        }
      }
    GRAPHQL

    user = query.new({
      "__typename" => "User",
      "id" => "1",
      "repositories" => [
        {
          "name" => "github",
          "watchers" => {
            "login" => "josh"
          }
        }
      ]
    })

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers.login
  end

  def test_query_result_with_inline_fragments
    query = GraphQL::Client::Query.parse(<<-'GRAPHQL')
      query UserQuery {
        id
        repositories {
          ... on Repository {
            name
            watchers {
              ... on User {
                login
              }
            }
          }
        }
      }
    GRAPHQL

    user = query.new({
      "id" => "1",
      "repositories" => [
        {
          "name" => "github",
          "watchers" => {
            "login" => "josh"
          }
        }
      ]
    })

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers.login
  end

  def test_nested_inline_fragments_on_same_node
    fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on Node {
        id,
        ... on User {
          login
          ... on AdminUser {
            password
          }
        }
        ... on Organization {
          name
        }
      }
    GRAPHQL

    user = fragment.new({
      "__typename" => "User",
      "id" => "1",
      "login" => "josh",
      "password" => "secret"
    })

    assert_equal "1", user.id
    assert_equal "josh", user.login
    assert_equal "secret", user.password
  end

  TestUserFragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
    fragment on User {
      login
    }
  GRAPHQL

  def test_fragment_spread_constant
    repo_fragment = GraphQL::Client::Fragment.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ...TestClientParse::TestUserFragment
        }
      }
    GRAPHQL

    repo = repo_fragment.new({
      "__typename" => "Repository",
      "name" => "rails",
      "owner" => {
        "__typename" => "User",
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name

    owner = TestUserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_nested_fragment_spread_constant
    doc = GraphQL::Client::Document.parse(<<-'GRAPHQL')
      fragment RepositoryFragment on Repository {
        name
        owner {
          ...TestClientParse::TestUserFragment
        }
      }

      query RepositoryQuery($id: ID!) {
        node(id: $id) {
          ...RepositoryFragment
        }
      }
    GRAPHQL

    repo = doc[:RepositoryFragment].new({
      "__typename" => "Repository",
      "name" => "rails",
      "owner" => {
        "__typename" => "User",
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name

    owner = TestUserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end
end
