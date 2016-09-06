require "graphql"
require "graphql/language/mutator"
require "graphql/language/nodes/deep_freeze_ext"
require "minitest/autorun"

class TestMutator < MiniTest::Test
  def test_prepend_selections
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        node(id: "4") {
          __typename
          id
          ... on User {
            name
            friends {
              name
            }
          }
        }
      }
    GRAPHQL

    mutator = GraphQL::Language::Mutator.new(document)
    mutator.prepend_selection(GraphQL::Language::Nodes::Field.new(name: "__typename").deep_freeze)

    expected = <<-'GRAPHQL'
      query FooQuery {
        __typename
        node(id: "4") {
          __typename
          id
          ... on User {
            __typename
            name
            friends {
              __typename
              name
            }
          }
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end
end
