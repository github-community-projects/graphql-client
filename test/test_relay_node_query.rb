require "graphql"
require "graphql/relay/node_query"
require "minitest/autorun"

class TestRelayNodeQuery < MiniTest::Test
  def test_node_query
    fragment = GraphQL.parse(<<-'GRAPHQL').definitions.first
      fragment UserFragment on User {
        login
      }
    GRAPHQL

    expected = <<-'GRAPHQL'
      query($id: ID!) {
        node(id: $id) {
          ... NodeFragment
        }
      }

      fragment NodeFragment on User {
        login
      }
    GRAPHQL
    query = GraphQL::Relay::NodeQuery(fragment)
    assert_equal expected.gsub(/^      /, "").chomp, GraphQL::Language::Nodes::Document.new(definitions: [query]).to_query_string
  end
end
