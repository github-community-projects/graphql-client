require "graphql"
require "graphql/client/http"
require "minitest/autorun"

class TestHTTP < MiniTest::Test
  def setup
    @http = GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")
  end

  def test_execute
    skip "TestHTTP disabled by default" unless __FILE__ == $PROGRAM_NAME

    document = GraphQL.parse(<<-'GRAPHQL')
      query getPerson($id: ID!) {
        person(personID: $id) {
          name
        }
      }
    GRAPHQL

    name = "getPerson"
    variables = { "id" => 4 }

    expected = {
      "data" => {
        "person" => {
          "name" => "Darth Vader"
        }
      }
    }
    actual = @http.execute(document: document, operation_name: name, variables: variables)
    assert_equal(expected, actual)
  end
end
