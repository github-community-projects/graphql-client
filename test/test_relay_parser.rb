require "graphql"
require "graphql/relay/parser"
require "minitest/autorun"

class TestRelayParser < MiniTest::Test
  def test_parse_anonymous_fragment
    document = GraphQL::Relay::Parser.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
      }
    GRAPHQL

    assert fragment = document.definitions.first
    assert_equal nil, fragment.name
    assert_equal "Person", fragment.type
  end
end
