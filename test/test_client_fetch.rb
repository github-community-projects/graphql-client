# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientFetch < MiniTest::Test
  class QueryType < GraphQL::Schema::Object
    field :version, Integer, null: false
    def version
      1
    end

    field :error, String, null: false
    def error
      raise GraphQL::ExecutionError, "b00m"
    end

    field :partial_error, String, null: true
    def partial_error
      raise GraphQL::ExecutionError, "just a little broken"
    end

    field :variables, Boolean, null: false do
      argument :foo, Integer, required: true
    end

    def variables(foo:)
      foo == 42
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
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

  def test_successful_response
    Temp.const_set :Query, @client.parse("{ version }")
    assert response = @client.query(Temp::Query)
    assert_equal 1, response.data.version
    assert_empty response.errors

    assert_equal({
      "data" => {
        "version" => 1
      }
    }, response.to_h)
  end

  def test_failed_validation_response
    query = Class.new(GraphQL::Schema::Object) do
      graphql_name "Query"
      field :err, String, null: true
    end

    outdated_schema = Class.new(GraphQL::Schema) do
      query(query)
      def self.resolve_type(_type, _obj, _ctx)
        raise NotImplementedError
      end
    end

    @client = GraphQL::Client.new(schema: outdated_schema, execute: Schema)

    Temp.const_set :Query, @client.parse("{ err }")
    assert response = @client.query(Temp::Query)
    refute response.data

    refute_empty response.errors
    assert_equal "Field 'err' doesn't exist on type 'Query'", response.errors[:data][0]

    refute_empty response.errors.all
    assert_equal "Field 'err' doesn't exist on type 'Query'", response.errors[:data][0]
  end

  def test_failed_response
    Temp.const_set :Query, @client.parse("{ error }")
    assert response = @client.query(Temp::Query)
    refute response.data

    refute_empty response.errors
    assert_equal "b00m", response.errors[:data][0]
  end

  def test_partial_response
    Temp.const_set :Query, @client.parse("{ partialError }")
    response = @client.query(Temp::Query)

    assert response.data
    assert_nil response.data.partial_error
    refute_empty response.data.errors
    assert_equal "just a little broken", response.data.errors["partialError"][0]

    assert_empty response.errors
    refute_empty response.errors.all
    assert_equal "just a little broken", response.errors.all[:data][0]
  end

  def test_query_with_string_key_variables
    Temp.const_set :Query, @client.parse("query($foo: Int!) { variables(foo: $foo) }")
    assert response = @client.query(Temp::Query, variables: { "foo" => 42 })
    assert_empty response.errors
    assert_equal true, response.data.variables
  end

  def test_query_with_symbol_key_variables
    Temp.const_set :Query, @client.parse("query($foo: Int!) { variables(foo: $foo) }")
    assert response = @client.query(Temp::Query, variables: { foo: 42 })
    assert_empty response.errors
    assert_equal true, response.data.variables
  end

  def test_dynamic_query_errors
    query = @client.parse("{ version }")

    assert_raises GraphQL::Client::DynamicQueryError do
      @client.query(query)
    end

    @client.allow_dynamic_queries = true
    assert @client.query(query)
  end
end
