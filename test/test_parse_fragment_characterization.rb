# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"

# Characterization tests pinning the CURRENT behavior of how Client#parse handles
# *inline named fragments* (a `fragment Name on Type { ... }` definition that lives in
# the same document as the operation that spreads `...Name`), as opposed to fragments
# bound to Ruby constants and spread by their constant path.
#
# These behaviors are exercised today only incidentally (the existing
# `test_client_parse_query_fragment_document` mixes a local spread with a constant
# spread). They are isolated here so that a future refactor of the fragment-resolution
# step in `Client#parse` cannot change them silently.
class TestParseFragmentCharacterization < Minitest::Test
  class UserType < GraphQL::Schema::Object
    field :id, ID, null: false
    field :name, String, null: false
    field :login, String, null: false
    field :friends, "[TestParseFragmentCharacterization::UserType]", null: false do
      argument :first, Int, required: false
    end
  end

  class QueryType < GraphQL::Schema::Object
    field :viewer, UserType, null: false
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
    @client.document_tracking_enabled = true
  end

  def teardown
    Temp.constants.each { |sym| Temp.send(:remove_const, sym) }
  end

  # A `...Name` spread that refers to a fragment defined in the SAME document — with no
  # Ruby constant named `Name` anywhere — is resolved locally: the fragment definition is
  # kept and renamed with the document's constant path, and the spread is rewritten to the
  # renamed name. No ValidationError is raised and no constant lookup is required.
  def test_local_named_fragment_spread_resolves_without_a_constant
    Temp.const_set :Doc, @client.parse(<<-'GRAPHQL')
      query Profile {
        user(id: 4) {
          ...UserFields
        }
      }

      fragment UserFields on User {
        id
        name
      }
    GRAPHQL

    op = Temp::Doc::Profile
    refute_nil op
    query_string = op.document.to_query_string

    assert_includes query_string, "query TestParseFragmentCharacterization__Temp__Doc__Profile"
    assert_includes query_string, "fragment TestParseFragmentCharacterization__Temp__Doc__UserFields on User"
    # the spread points at the renamed local fragment, not a bare `...UserFields`
    assert_includes query_string, "...TestParseFragmentCharacterization__Temp__Doc__UserFields"
    refute_match(/\.\.\.UserFields\b/, query_string)
  end

  # Transitive local fragments (a local fragment that itself spreads another local
  # fragment) are all resolved and renamed locally, and the operation's sliced document
  # carries the full transitive dependency chain.
  def test_transitive_local_named_fragments_resolve
    Temp.const_set :Doc, @client.parse(<<-'GRAPHQL')
      query Profile {
        user(id: 4) {
          ...Outer
        }
      }

      fragment Outer on User {
        id
        ...Inner
      }

      fragment Inner on User {
        name
      }
    GRAPHQL

    document = Temp::Doc::Profile.document
    # operation + both transitively-required fragments
    assert_equal 3, document.definitions.size
    query_string = document.to_query_string
    assert_includes query_string, "...TestParseFragmentCharacterization__Temp__Doc__Outer"
    assert_includes query_string, "...TestParseFragmentCharacterization__Temp__Doc__Inner"
    assert_includes query_string, "fragment TestParseFragmentCharacterization__Temp__Doc__Inner on User"
  end

  # For a document with multiple independent operations, each operation's `document` is
  # SLICED to just that operation plus its own fragment dependencies, while
  # `source_document` retains every sibling definition from the original parse.
  def test_source_document_retains_siblings_while_document_is_sliced
    Temp.const_set :Doc, @client.parse(<<-'GRAPHQL')
      query A {
        user(id: 4) {
          ...FieldsA
        }
      }

      query B {
        viewer {
          ...FieldsB
        }
      }

      fragment FieldsA on User {
        id
      }

      fragment FieldsB on User {
        name
      }
    GRAPHQL

    a = Temp::Doc::A
    # sliced: query A + fragment FieldsA only
    assert_equal 2, a.document.definitions.size
    # source: all four definitions from the original document
    assert_equal 4, a.source_document.definitions.size
  end
end
