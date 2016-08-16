require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/replace_fragment_spread_ext"
require "minitest/autorun"

class TestReplaceFragmentSpreadExt < MiniTest::Test
  def test_query_replace_fragment_spread
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "4") {
          id
          ... UserFragment
          ... MissingFragment
        }
      }

      fragment UserFragment on User {
        name
        friends {
          name
        }
      }
    GRAPHQL

    query, fragment = document.definitions

    new_query = query.replace_fragment_spread({
      :"UserFragment" => fragment
    })
    refute new_query.frozen?

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "4") {
          id
          ... on User {
            name
            friends {
              name
            }
          }
          ... MissingFragment
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, GraphQL::Language::Nodes::Document.new(definitions: [new_query]).to_query_string
  end

  def test_document_replace_fragment_spread
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "4") {
          id
          ... UserFragment
          ... MissingFragment
        }
      }

      fragment UserFragment on User {
        name
        friends {
          name
        }
      }
    GRAPHQL

    _, fragment = document.definitions

    new_document = document.replace_fragment_spread({
      :"UserFragment" => fragment
    })
    refute new_document.frozen?

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "4") {
          id
          ... on User {
            name
            friends {
              name
            }
          }
          ... MissingFragment
        }
      }

      fragment UserFragment on User {
        name
        friends {
          name
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end
end
