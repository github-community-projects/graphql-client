# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/definition_variables"
require "minitest/autorun"

class TestDefinitionVariables < MiniTest::Test
  class QueryType < GraphQL::Schema::Object
    field :version, Integer, null: false
    field :user, String, null: false do
      argument :name, String, required: true
      argument :maybe_name, String, required: false
    end
    field :node, String, null: false do
      argument :id, ID, required: true
    end
  end

  class CreateUserInput < GraphQL::Schema::InputObject
    argument :name, String, required: true
  end

  class MutationType < GraphQL::Schema::Object
    field :create_user, String, null: true do
      argument :input, CreateUserInput, required: true
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
    mutation(MutationType)
  end

  def test_query_with_no_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        version
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables.empty?
  end

  def test_fragment_with_no_variables
    document = GraphQL.parse <<-'GRAPHQL'
      fragment on Query {
        version
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables.empty?
  end

  def test_query_with_one_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:name].kind.non_null?
    assert_equal "String", variables[:name].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_one_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        ...Foo
      }

      fragment Foo on Query {
        user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:name].kind.non_null?
    assert_equal "String", variables[:name].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_unused_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        ...One
      }

      fragment One on Query {
        one: user(name: $one)
      }

      fragment Two on Query {
        two: user(name: $two)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:one].kind.non_null?
    assert_equal "String", variables[:one].unwrap.graphql_name
    assert_equal false, variables.key?(:two)

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$one: String!"], variables.map(&:to_query_string)
  end

  def test_query_nullable_and_nonnullable_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $foo, maybeName: $bar)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:foo].kind.non_null?
    assert_equal "String", variables[:foo].unwrap.graphql_name
    assert_equal "String", variables[:bar].graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$foo: String!", "$bar: String"], variables.map(&:to_query_string)
  end


  def test_query_variable_used_twice
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $name)
        two: user(name: $name)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:name].kind.non_null?
    assert_equal "String", variables[:name].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_same_nullable_and_nonnullable_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        one: user(name: $foo, maybeName: $foo)
        two: user(maybeName: $bar, name: $bar)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:foo].kind.non_null?
    assert_equal "String", variables[:foo].unwrap.graphql_name
    assert variables[:bar].kind.non_null?
    assert_equal "String", variables[:bar].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$foo: String!", "$bar: String!"], variables.map(&:to_query_string)
  end

  def test_fragment_with_unused_nested_variable
    document = GraphQL.parse <<-'GRAPHQL'
      fragment Root on Query {
        ...One
      }

      fragment One on Query {
        one: user(name: $one)
      }

      fragment Two on Query {
        two: user(name: $two)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:one].kind.non_null?
    assert_equal "String", variables[:one].unwrap.graphql_name
    assert_equal false, variables.key?(:two)

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$one: String!"], variables.map(&:to_query_string)
  end

  def test_mutation_with_input_type_variable
    document = GraphQL.parse <<-'GRAPHQL'
      mutation {
        createUser(input: $input)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:input].kind.non_null?
    assert_equal "CreateUserInput", variables[:input].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$input: CreateUserInput!"], variables.map(&:to_query_string)
  end

  def test_mutation_with_nested_input_type_variable
    document = GraphQL.parse <<-'GRAPHQL'
      mutation {
        createUser(input: { name: $name })
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:name].kind.non_null?
    assert_equal "String", variables[:name].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$name: String!"], variables.map(&:to_query_string)
  end

  def test_query_with_one_directive_variables
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        version @skip(if: $should_skip)
      }
    GRAPHQL
    definition = document.definitions[0]

    variables = GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    assert variables[:should_skip].kind.non_null?
    assert_equal "Boolean", variables[:should_skip].unwrap.graphql_name

    variables = GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    assert_equal ["$should_skip: Boolean!"], variables.map(&:to_query_string)
  end

  def test_query_with_conflicting_variable_types
    document = GraphQL.parse <<-'GRAPHQL'
      query {
        node(id: $id)
        user(name: $id)
      }
    GRAPHQL
    definition = document.definitions[0]

    assert_raises GraphQL::Client::ValidationError do
      GraphQL::Client::DefinitionVariables.variables(Schema, document, definition.name)
    end

    assert_raises GraphQL::Client::ValidationError do
      GraphQL::Client::DefinitionVariables.operation_variables(Schema, document, definition.name)
    end
  end
end
