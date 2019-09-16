# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientCreateOperation < MiniTest::Test
  class UserType < GraphQL::Schema::Object
    field :id, ID, null: false
  end

  class QueryType < GraphQL::Schema::Object
    field :version, Int, null: false
    field :user, UserType, null: true do
      argument :name, String, required: true
    end
    field :users, [UserType], null: false do
      argument :name, String, required: false
      argument :names, [String], required: false
    end
  end

  class CreateUserInput < GraphQL::Schema::InputObject
    argument :name, String, required: true
  end

  class MutationType < GraphQL::Schema::Object
    field :create_user, UserType, null: true do
      argument :input, CreateUserInput, required: true
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
    mutation(MutationType)

    use GraphQL::Execution::Interpreter
    use GraphQL::Analysis::AST
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema, execute: Schema)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_query_from_fragment_with_on_wrong_query_type
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
      }
    GRAPHQL

    assert_raises GraphQL::Client::Error, "Fragment must be defined on Query, Mutation" do
      @client.create_operation(Temp::Fragment)
    end
  end

  def test_query_from_fragment_with_no_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        version
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        version
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_one_non_nullable_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        user(name: $name) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($name: String!) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        user(name: $name) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_one_nullable_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        users(name: $name) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($name: String) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        users(name: $name) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_query_from_fragment_with_list_of_scalar_variables
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        users(names: $names) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClientCreateOperation__Temp__Query($names: [String!]) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Query {
        users(names: $names) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end

  def test_mutation_from_fragment_with_input_type_variable
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Mutation {
        createUser(input: $input) {
          id
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.create_operation(Temp::Fragment)

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClientCreateOperation__Temp__Query($input: CreateUserInput!) {
        ...TestClientCreateOperation__Temp__Fragment
      }

      fragment TestClientCreateOperation__Temp__Fragment on Mutation {
        createUser(input: $input) {
          id
        }
      }
    GRAPHQL
    assert_equal(query_string, Temp::Query.document.to_query_string)
  end
end
