require "graphql"
require "graphql/client"
require "minitest/autorun"

class TestClientFetch < MiniTest::Test
  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int do
      resolve -> (_query, _args, _ctx) { 1 }
    end
    field :error, !types.String do
      resolve -> (_query, _args, _ctx) { raise GraphQL::ExecutionError, "b00m" }
    end
    field :partial_error, types.String do
      resolve -> (_query, _args, _ctx) { raise GraphQL::ExecutionError, "just a little broken" }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)

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
  end

  def test_failed_validation_response
    @client = GraphQL::Client.new(schema: nil, execute: Schema)

    Temp.const_set :Query, @client.parse("{ err }")
    assert response = @client.query(Temp::Query)
    refute response.data

    refute_empty response.errors
    assert_equal "Field 'err' doesn't exist on type 'Query'", response.errors[:base][0]
  end

  def test_failed_response
    Temp.const_set :Query, @client.parse("{ error }")
    assert response = @client.query(Temp::Query)
    refute response.data

    skip
    refute_empty response.errors
    assert_equal "b00m", response.errors[:base][0]
  end

  def test_partial_response
    Temp.const_set :Query, @client.parse("{ partial_error }")
    response = @client.query(Temp::Query)

    assert_empty response.errors
    refute_empty response.all_errors
    assert_equal "just a little broken", response.all_errors[:base][0]

    assert_equal nil, response.data.partial_error
    refute_empty response.data.errors
    assert_equal "just a little broken", response.data.errors["partial_error"][0]
  end
end
