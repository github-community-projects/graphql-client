require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/nodes/document_definition_slice_ext"
require "minitest/autorun"

class TestDocumentDefinitionSliceExt < MiniTest::Test
  def test_slice_simple_query_operation
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          id
        }
      }
    GRAPHQL

    new_document = document.definition_slice("FooQuery")

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "42") {
          id
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_simple_mutation_operation
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      mutation FooMutation {
        incr {
          count
        }
      }
    GRAPHQL

    new_document = document.definition_slice("FooMutation")

    expected = <<-'GRAPHQL'
      mutation FooMutation {
        incr {
          count
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_simple_fragment_definition
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      fragment FooFragment on Node {
        id
      }
    GRAPHQL

    new_document = document.definition_slice("FooFragment")

    expected = <<-'GRAPHQL'
      fragment FooFragment on Node {
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_query_with_fragment
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          ... NodeFragment
        }
      }

      fragment NodeFragment on Node {
        id
      }

      fragment UnusedFragment on Node {
        __typename
      }
    GRAPHQL

    new_document = document.definition_slice("FooQuery")

    expected = <<-'GRAPHQL'
      query FooQuery {
        node(id: "42") {
          ... NodeFragment
        }
      }

      fragment NodeFragment on Node {
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end
end
