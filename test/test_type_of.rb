# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"
require "ostruct"

class TestTypeOf < MiniTest::Test
  ResultType = GraphQL::InterfaceType.define do
    name "Result"
    field :id, !types.ID
  end

  NodeType = GraphQL::InterfaceType.define do
    name "Node"
    field :id, !types.ID
  end

  PersonType = GraphQL::ObjectType.define do
    name "Person"
    interfaces [NodeType]
    field :id, !types.ID
  end

  MeType = GraphQL::UnionType.define do
    name "Me"
    possible_types [PersonType]
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          id: "123"
        )
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    orphan_types [ResultType, MeType]
    resolve_type ->(_obj, _ctx) { raise NotImplementedError }
  end
  Client = GraphQL::Client.new(schema: Schema, execute: Schema)

  Query = Client.parse(<<-'GRAPHQL')
    {
      me {
        id
      }
    }
  GRAPHQL

  def test_type_of
    response = Client.query(Query)

    assert response.data.type_of?(:Query)
    assert response.data.type_of?("Query")
    assert response.data.type_of?(QueryType)
    refute response.data.type_of?(:Me)
    refute response.data.type_of?(:Node)
    refute response.data.type_of?(:Null)
    refute response.data.type_of?(:Person)
    refute response.data.type_of?("Me")
    refute response.data.type_of?("Node")
    refute response.data.type_of?("Person")
    refute response.data.type_of?(MeType)
    refute response.data.type_of?(NodeType)
    refute response.data.type_of?(PersonType)

    assert response.data.me.type_of?(:Me)
    assert response.data.me.type_of?(:Node)
    assert response.data.me.type_of?(:Person)
    assert response.data.me.type_of?("Me")
    assert response.data.me.type_of?("Node")
    assert response.data.me.type_of?("Person")
    assert response.data.me.type_of?(MeType)
    assert response.data.me.type_of?(NodeType)
    assert response.data.me.type_of?(PersonType)
    refute response.data.me.type_of?(:Null)
    refute response.data.me.type_of?(:Query)
    refute response.data.me.type_of?(:Result)
    refute response.data.me.type_of?("Query")
    refute response.data.me.type_of?("Result")
    refute response.data.me.type_of?(QueryType)
    refute response.data.me.type_of?(ResultType)
  end
end
