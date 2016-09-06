require "graphql"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/operation_slice"
require "minitest/autorun"

class TestOperationSlice < MiniTest::Test
  def test_slice_simple_query_operation
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          id
        }
      }
    GRAPHQL

    new_document = GraphQL::Language::OperationSlice.slice(document, "FooQuery")

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

    new_document = GraphQL::Language::OperationSlice.slice(document, "FooMutation")

    expected = <<-'GRAPHQL'
      mutation FooMutation {
        incr {
          count
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end

  def test_slice_query_with_fragment
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment NodeFragment on Node {
        id
      }

      fragment UnusedFragment on Node {
        type
      }
    GRAPHQL

    new_document = GraphQL::Language::OperationSlice.slice(document, "FooQuery")

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

  def test_slice_nested_query_with_fragment
    document = GraphQL.parse(<<-'GRAPHQL').deep_freeze
      fragment NodeFragment on Node {
        id
        ...UserFragment
        ...AnotherUserFragment
      }

      query FooQuery {
        node(id: "42") {
          ...NodeFragment
        }
      }

      fragment AnotherUnusedFragment on Project {
        number
      }

      fragment AnotherUserFragment on Node {
        company
      }

      fragment UserFragment on Node {
        name
        ...AnotherUserFragment
      }

      fragment UnusedFragment on Node {
        type
        ...AnotherUnusedFragment
      }
    GRAPHQL

    new_document = GraphQL::Language::OperationSlice.slice(document, "FooQuery")

    expected = <<-'GRAPHQL'
      fragment NodeFragment on Node {
        id
        ... UserFragment
        ... AnotherUserFragment
      }

      query FooQuery {
        node(id: "42") {
          ... NodeFragment
        }
      }

      fragment AnotherUserFragment on Node {
        company
      }

      fragment UserFragment on Node {
        name
        ... AnotherUserFragment
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, new_document.to_query_string
  end
end
