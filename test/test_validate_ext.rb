require "graphql"
require "graphql/language/nodes/validate_ext"
require "minitest/autorun"

class TestValidateExt < MiniTest::Test
  UserType = GraphQL::ObjectType.define do
    name "User"
    field :id, !types.ID
    field :name, !types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :viewer, UserType
  end

  Schema = GraphQL::Schema.new(query: QueryType)

  def test_validate_document
    document = GraphQL.parse(<<-'GRAPHQL')
      query UserQuery {
        viewer {
          id
          name
        }
      }
    GRAPHQL
    document.validate!(schema: Schema)

    document = GraphQL.parse(<<-'GRAPHQL')
      query UserQuery {
        viewer {
          id
          fullName
        }
      }
    GRAPHQL

    assert_raises GraphQL::ValidationError do
      document.validate!(schema: Schema)
    end
  end

  def test_validate_query
    query = GraphQL.parse(<<-'GRAPHQL').definitions.first
      query UserQuery {
        viewer {
          id
          name
        }
      }
    GRAPHQL
    query.validate!(schema: Schema)

    query = GraphQL.parse(<<-'GRAPHQL').definitions.first
      query UserQuery {
        viewer {
          id
          fullName
        }
      }
    GRAPHQL

    assert_raises GraphQL::ValidationError do
      query.validate!(schema: Schema)
    end
  end

  def test_validate_fragment_definition
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment UserFragment on User {
        id
        name
      }
    GRAPHQL
    fragment.validate!(schema: Schema)

    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment UserFragment on User {
        id
        fullName
      }
    GRAPHQL

    assert_raises GraphQL::ValidationError do
      fragment.validate!(schema: Schema)
    end
  end

  def test_validate_inline_fragment
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first.selections.first
      {
        ... on User {
          id
          name
        }
      }
    GRAPHQL
    fragment.validate!(schema: Schema)

    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first.selections.first
      {
        ... on User {
          id
          fullName
        }
      }
    GRAPHQL

    assert_raises GraphQL::ValidationError do
      fragment.validate!(schema: Schema)
    end
  end
end
