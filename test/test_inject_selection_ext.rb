require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/inject_selection_ext"
require "minitest/autorun"

class TestInjectSelectionExt < MiniTest::Test
  def test_has_selections
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "4") {
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

    new_document = document.inject_selection(GraphQL::Language::Nodes::Field.new(name: "__typename"))
    refute new_document.frozen?

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
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end
end
