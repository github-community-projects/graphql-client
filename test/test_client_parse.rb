require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientParse < MiniTest::Test
  TestUserFragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
    fragment on User {
      login
    }
  GRAPHQL

  def test_assigned_constant_name
    assert_equal "TestClientParse::TestUserFragment", TestUserFragment.name
  end

  def test_parse_fragment
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    assert_equal "User", fragment.source_node.type
    assert_equal "login", fragment.source_node.selections[1].name
  end

  def test_parse_query
    query = GraphQL::Client.parse_query(<<-'GRAPHQL')
      query UserQuery {
        viewer {
          login
        }
      }
    GRAPHQL

    assert_equal "query", query.source_node.operation_type
    assert_equal "UserQuery", query.source_node.name
    assert_equal "viewer", query.source_node.selections[1].name
    assert_equal "login", query.source_node.selections[1].selections[1].name
  end

  def test_parse_document
    document = GraphQL::Client.parse_document(<<-'GRAPHQL')
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

    assert_equal "viewer", document[:UserQuery].source_node.selections[1].name
    assert_equal "login", document[:UserFragment].source_node.selections[1].name
    assert_equal "name", document[:RepositoryFragment].source_node.selections[1].name
  end

  def test_parse_query_wrong_type
    assert_raises ArgumentError do
      GraphQL::Client.parse_query(<<-'GRAPHQL')
        fragment on User {
          login
        }
      GRAPHQL
    end
  end

  def test_parse_fragment_wrong_type
    assert_raises ArgumentError do
      GraphQL::Client.parse_fragment(<<-'GRAPHQL')
        query UserQuery {
          viewer {
            login
          }
        }
      GRAPHQL
    end
  end

  def test_fragment_query_result_with_one_field
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    user = fragment.new({"__typename" => "User", "login" => "josh"})
    assert_equal "josh", user.login
  end

  def test_fragment_query_result_with_multiple_field
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
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
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
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
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
      fragment on User {
        name: profileName
      }
    GRAPHQL

    user = fragment.new({"name" => "Josh"})
    assert_equal "Josh", user.name
  end

  def test_fragment_query_result_with_nested_fields
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
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
    query = GraphQL::Client.parse_query(<<-'GRAPHQL')
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
    query = GraphQL::Client.parse_query(<<-'GRAPHQL')
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
    fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
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

  def test_fragment_spread_constant
    repo_fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
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
    refute repo.owner.respond_to?(:login)

    owner = TestUserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_invalid_fragment_cast
    repo_fragment = GraphQL::Client.parse_fragment(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          login
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
    assert_equal "josh", repo.owner.login

    assert_raises TypeError do
      TestUserFragment.new(repo.owner)
    end
  end
end
