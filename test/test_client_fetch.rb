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
    response = @client.query(Temp::Query)
    assert_kind_of GraphQL::Client::SuccessfulResponse, response
    assert_equal 1, response.data.version
  end

  def test_failed_response
    Temp.const_set :Query, @client.parse("{ error }")
    response = @client.query(Temp::Query)
    assert_kind_of GraphQL::Client::FailedResponse, response
    assert_equal GraphQL::Client::ResponseErrors.new(Temp::Query, [
                                                       {
                                                         "message" => "b00m",
                                                         "locations" => [{ "line" => 2, "column" => 3 }]
                                                       }
                                                     ]), response.errors
  end

  def test_partial_response
    Temp.const_set :Query, @client.parse("{ partial_error }")
    response = @client.query(Temp::Query)
    assert_kind_of GraphQL::Client::PartialResponse, response
    assert_equal nil, response.data.partial_error
    assert_equal GraphQL::Client::ResponseErrors.new(Temp::Query, [
                                                       {
                                                         "message" => "just a little broken",
                                                         "locations" => [{ "line" => 2, "column" => 3 }]
                                                       }
                                                     ]), response.errors
  end
end
