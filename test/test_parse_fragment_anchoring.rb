# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

# Regression tests for anchoring the fragment-_definition_ detection in `Client#parse`.
#
# When `#parse` walks `...Name` spreads it must decide, for each spread, whether `Name`
# refers to a named fragment _defined in the same document_ (leave it untouched) or to a
# Ruby constant that has to be resolved. That decision used to be made with the unanchored
# `/fragment\s*#{const_name}/`, which matched too eagerly:
#
#   * `\s*` allowed zero whitespace (`fragmentName` would match), and
#   * there was no boundary after the name, so `...UserFields` matched a
#     `fragment UserFieldsExtended on User` definition.
#
# The match is now anchored to `fragment <Name> on` with mandatory surrounding whitespace.
class TestParseFragmentAnchoring < Minitest::Test
  class UserType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :name, String, null: false
  end

  class QueryType < GraphQL::Schema::Object
    field :user, UserType, null: true do
      argument :id, ID, required: true
    end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema)
  end

  def teardown
    Temp.constants.each { |sym| Temp.send(:remove_const, sym) }
  end

  # A spread whose name is a PREFIX of an inline fragment's name must NOT be mistaken for
  # that fragment's definition. `...UserFields` has no `fragment UserFields on ...` and no
  # matching constant, so it has to surface as an unresolved constant — not be silently
  # left in place by colliding with `fragment UserFieldsExtended on User`.
  def test_prefix_spread_is_not_swallowed_by_a_longer_fragment_definition
    error = assert_raises(GraphQL::Client::ValidationError) do
      @client.parse(<<-'GRAPHQL')
        query Profile {
          user(id: 4) {
            ...UserFields
            ...UserFieldsExtended
          }
        }

        fragment UserFieldsExtended on User {
          id
          name
        }
      GRAPHQL
    end

    assert_match(/uninitialized constant UserFields/, error.message)
  end

  # The anchoring must not be too strict: when both a short and a longer (prefix-sharing)
  # named fragment are defined inline and both are spread, both resolve locally with no
  # error and both definitions are carried in the document.
  def test_prefix_sharing_inline_fragments_both_resolve
    Temp.const_set :Doc, @client.parse(<<-'GRAPHQL')
      query Profile {
        user(id: 4) {
          ...UserFields
          ...UserFieldsExtended
        }
      }

      fragment UserFields on User {
        id
      }

      fragment UserFieldsExtended on User {
        id
        name
      }
    GRAPHQL

    query_string = Temp::Doc::Profile.document.to_query_string
    assert_includes query_string, "fragment TestParseFragmentAnchoring__Temp__Doc__UserFields on User"
    assert_includes query_string, "fragment TestParseFragmentAnchoring__Temp__Doc__UserFieldsExtended on User"
    assert_includes query_string, "...TestParseFragmentAnchoring__Temp__Doc__UserFields"
    assert_includes query_string, "...TestParseFragmentAnchoring__Temp__Doc__UserFieldsExtended"
  end

  # The realistic interop case: a pre-existing *constant* fragment spread coexisting in the
  # SAME document with a newly-added *inline* named fragment whose name shares its prefix.
  # This is exactly where the unanchored match silently broke — the constant spread
  # `...ReuseFields` was mistaken for the inline `fragment ReuseFieldsFull on User`
  # definition, so the constant was never resolved (and parsing later crashed). Both styles
  # must now resolve side by side.
  def test_constant_spread_and_prefix_sharing_inline_fragment_coexist
    Object.const_set :ReuseFields, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
      }
    GRAPHQL

    Temp.const_set :Doc, @client.parse(<<-'GRAPHQL')
      query Profile {
        user(id: 4) {
          ...ReuseFields
          ...ReuseFieldsFull
        }
      }

      fragment ReuseFieldsFull on User {
        id
        name
      }
    GRAPHQL

    query_string = Temp::Doc::Profile.document.to_query_string
    # the constant spread resolved to the top-level constant's fragment (kept bare name)
    assert_includes query_string, "fragment ReuseFields on User"
    assert_match(/\.\.\.ReuseFields\b/, query_string)
    # the prefix-sharing inline fragment resolved locally, renamed under the document path
    assert_includes query_string, "fragment TestParseFragmentAnchoring__Temp__Doc__ReuseFieldsFull on User"
    assert_includes query_string, "...TestParseFragmentAnchoring__Temp__Doc__ReuseFieldsFull"
  ensure
    Object.send(:remove_const, :ReuseFields) if Object.const_defined?(:ReuseFields)
  end
end
