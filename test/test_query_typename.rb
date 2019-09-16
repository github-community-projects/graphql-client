# frozen_string_literal: true
require "graphql"
require "graphql/client/query_typename"
require "minitest/autorun"

class TestQueryTypename < MiniTest::Test
  class PersonType < GraphQL::Schema::Object
    field :id, Integer, null: true
    def id; 42; end

    field :friends, "TestQueryTypename::PersonConnection", null: true
    def friends; [OpenStruct.new, OpenStruct.new]; end

    field :events, "TestQueryTypename::EventConnection", null: true
    def events; [OpenStruct.new(type: PublicEventType), OpenStruct.new(type: PrivateEventType)]; end

    field :next_event, "TestQueryTypename::EventInterface", null: true
    def next_event
      OpenStruct.new(type: PublicEventType)
    end
  end

  module EventInterface
    include GraphQL::Schema::Interface
    field :id, Integer, null: true
    def id; 42; end
  end

  class PublicEventType < GraphQL::Schema::Object
    implements EventInterface
  end

  class PrivateEventType < GraphQL::Schema::Object
    implements EventInterface
  end

  class Event < GraphQL::Schema::Union
    possible_types PublicEventType, PrivateEventType
  end

  PersonConnection = PersonType.connection_type
  EventConnection = Event.connection_type

  class QueryType < GraphQL::Schema::Object
    field :me, PersonType, null: false
    def me; OpenStruct.new; end
  end

  class Schema < GraphQL::Schema
    query(QueryType)
    def self.resolve_type(_type, obj, _ctx)
      obj.type
    end
  end

  def setup
    @document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            id
            ...EventFragment
          }
          friends {
            edges {
              node {
                id
              }
            }
          }
          events {
            edges {
              node {
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        id
        nextEvent {
          id
        }
      }

      fragment EventFragment on Event {
        id
      }
    GRAPHQL
  end

  def test_insert_typename
    document = GraphQL::Client::QueryTypename.insert_typename_fields(@document)

    expected = <<-'GRAPHQL'
      query FooQuery {
        __typename
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            __typename
            id
            ...EventFragment
          }
          friends {
            __typename
            edges {
              __typename
              node {
                __typename
                id
              }
            }
          }
          events {
            __typename
            edges {
              __typename
              node {
                __typename
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        __typename
        id
        nextEvent {
          __typename
          id
        }
      }

      fragment EventFragment on Event {
        __typename
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end

  def test_insert_schema_aware_typename
    types = GraphQL::Client::DocumentTypes.analyze_types(Schema, @document)
    document = GraphQL::Client::QueryTypename.insert_typename_fields(@document, types: types)

    expected = <<-'GRAPHQL'
      query FooQuery {
        me {
          id
          __typename
          ...PersonFragment
          nextEvent {
            __typename
            id
            ...EventFragment
          }
          friends {
            edges {
              node {
                id
              }
            }
          }
          events {
            edges {
              node {
                __typename
                ... on PublicEvent {
                  id
                }
                ... on PrivateEvent {
                  id
                }
              }
            }
          }
        }
      }

      fragment PersonFragment on Person {
        id
        nextEvent {
          __typename
          id
        }
      }

      fragment EventFragment on Event {
        __typename
        id
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end

  def test_insert_typename_on_empty_selections
    document = GraphQL.parse(<<-'GRAPHQL')
      query FooQuery {
        me
      }
    GRAPHQL

    types = GraphQL::Client::DocumentTypes.analyze_types(Schema, document)
    document = GraphQL::Client::QueryTypename.insert_typename_fields(document, types: types)

    expected = <<-'GRAPHQL'
      query FooQuery {
        me {
          __typename
        }
      }
    GRAPHQL
    assert_equal expected.gsub(/^      /, "").chomp, document.to_query_string
  end
end
