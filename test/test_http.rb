# frozen_string_literal: true
require "graphql"
require "graphql/client/http"
require "minitest/autorun"
require "minitest/mock"

class TestHTTP < Minitest::Test
  SWAPI = GraphQL::Client::HTTP.new("https://mpjk0plp9.lp.gql.zone/graphql") do
    def headers(_context)
      { "User-Agent" => "GraphQL/1.0" }
    end
  end

  def test_execute
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME

    document = GraphQL.parse(<<-'GRAPHQL')
      query getCharacter($id: ID!) {
        character(id: $id) {
          name
        }
      }
    GRAPHQL

    name = "getCharacter"
    variables = { "id" => "1001" }

    expected = {
      "data" => {
        "character" => {
          "name" => "Darth Vader"
        }
      }
    }
    actual = SWAPI.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
  end
end

class TestHTTPParseResponse < Minitest::Test
  class UnexpectedStatus < StandardError; end

  def http_response(status, body)
    response = Net::HTTPResponse::CODE_TO_OBJ.fetch(status).new("1.1", status, "Test response")
    response.instance_variable_set(:@read, true)
    response.body = body
    response
  end

  def execute(adapter, response)
    connection = Minitest::Mock.new
    connection.expect(:request, response, [Net::HTTP::Post])
    result = adapter.stub(:connection, connection) do
      adapter.execute(document: GraphQL.parse("{ name }"))
    end
    connection.verify
    result
  end

  def test_default_response_handling
    adapter = GraphQL::Client::HTTP.new("https://example.com/graphql")

    assert_equal({ "data" => { "name" => "Luke" } }, execute(adapter, http_response("200", '{"data":{"name":"Luke"}}')))
    assert_equal({ "errors" => [{ "message" => "Rejected" }] }, execute(adapter, http_response("400", '{"errors":[{"message":"Rejected"}]}')))
    assert_equal({ "errors" => [{ "message" => "503 Test response" }] }, execute(adapter, http_response("503", "unavailable")))
  end

  def test_parse_response_can_be_overridden
    adapter = GraphQL::Client::HTTP.new("https://example.com/graphql") do
      def parse_response(response)
        raise UnexpectedStatus, response.code unless response.is_a?(Net::HTTPOK)

        super
      end
    end
    response = http_response("503", "<html>Unavailable</html>")

    error = assert_raises(UnexpectedStatus) { execute(adapter, response) }
    assert_equal("503", error.message)
    assert_equal(response.to_hash, adapter.last_response)
    assert_equal({ "data" => { "name" => "Luke" } }, execute(adapter, http_response("200", '{"data":{"name":"Luke"}}')))
  end
end
