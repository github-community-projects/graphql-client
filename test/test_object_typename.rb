# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"
require "ostruct"

class TestObjectTypename < MiniTest::Test
  class PersonType < GraphQL::Schema::Object
    field :id, Integer, null: true
    def id; 42; end

    field :friends, "TestObjectTypename::PersonConnection", null: true
    def friends; [OpenStruct.new, OpenStruct.new]; end

    field :events, "TestObjectTypename::EventConnection", null: true
    def events; [OpenStruct.new(type: PublicEventType), OpenStruct.new(type: PrivateEventType)]; end

    field :next_event, "TestObjectTypename::EventInterface", null: true
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

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema, execute: Schema)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_define_simple_query_result
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          id
          nextEvent {
            id
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
    GRAPHQL

    response = @client.query(Temp::Query)
    assert data = response.data

    assert_equal "Person", data.me.class.type.graphql_name

    assert_equal "PersonConnection", data.me.friends.class.type.graphql_name
    assert_equal %w(PersonEdge PersonEdge), data.me.friends.edges.map { |obj| obj.class.type.graphql_name }
    assert_equal %w(Person Person), data.me.friends.edges.map(&:node).map { |obj| obj.class.type.graphql_name }

    assert_equal "EventConnection", data.me.events.class.type.graphql_name
    assert_equal %w(EventEdge EventEdge), data.me.events.edges.map { |obj| obj.class.type.graphql_name }
    assert_equal %w(PublicEvent PrivateEvent), data.me.events.edges.map(&:node).map { |obj| obj.class.type.graphql_name }

    assert_equal "PublicEvent", data.me.next_event.class.type.graphql_name
  end
end
