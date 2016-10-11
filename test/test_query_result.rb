require "graphql"
require "graphql/client"
require "graphql/client/query_result"
require "minitest/autorun"
require "ostruct"

class TestQueryResult < MiniTest::Test
  PersonType = GraphQL::ObjectType.define do
    name "Person"
    field :login, types.String
    field :name, types.String
    field :firstName, types.String
    field :lastName, types.String
    field :company, types.String
    field :homepageURL, types.String
  end

  PersonConnection = PersonType.define_connection do
    name "PersonConnection"
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve -> (_query, _args, _ctx) {
        OpenStruct.new(
          login: "josh",
          name: "Josh",
          firstName: "Joshua",
          lastName: "Peek",
          company: "GitHub"
        )
      }
    end

    connection :users, PersonConnection do
      argument :first, types.Int

      resolve -> (_query, _args, _ctx) {
        [
          OpenStruct.new(login: "josh"),
          OpenStruct.new(login: "mislav")
        ]
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType)

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
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.respond_to?(:name)
    refute response.data.me.respond_to?(:company)

    person = Temp::Person.new(response.data.me)
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_snakecase_field_aliases
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        firstName
        lastName
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
  end

  def test_predicate_aliases
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        homepageURL
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal true, person.name?
    assert_equal false, person.homepage_url?
  end

  def test_field_alises
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        nickname: name
        currentCompany: company
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal "Josh", person.nickname
    assert_equal "GitHub", person.current_company
  end

  def test_no_method_error
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    begin
      person.nickname
      flunk
    rescue NoMethodError => e
      assert_equal "undefined method `nickname' for #<TestQueryResult::Temp::Person.type name=\"Josh\">", e.to_s
    end
  end

  def test_merge_classes
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        ... on Person {
          name
          company
        }

        ... on Person {
          name
          login
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)
    assert_equal "josh", person.login
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_merge_nested_classes
    Temp.const_set :Me, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        ... on Query {
          me {
            name
            company
          }
        }

        ... on Query {
          me {
            name
            login
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        ...TestQueryResult::Temp::Me
      }
    GRAPHQL

    person = Temp::Me.new(@client.query(Temp::Query).data)
    assert_equal "josh", person.me.login
    assert_equal "Josh", person.me.name
    assert_equal "GitHub", person.me.company
  end

  def test_relay_connection_enumerator
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        users(first: 2) {
          edges {
            cursor
            node {
              login
            }
          }
        }
      }
    GRAPHQL

    data = @client.query(Temp::Query).data
    assert_equal 2, data.users.edges.length
    assert_equal "josh", data.users.edges[0].node.login
    assert_equal "mislav", data.users.edges[1].node.login
    assert_equal %w(josh mislav), data.users.each_node.map(&:login)
  end
end
