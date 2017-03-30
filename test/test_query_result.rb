# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/query_result"
require "minitest/autorun"
require "ostruct"
require_relative "foo_helper"

class TestQueryResult < MiniTest::Test
  DateTime = GraphQL::ScalarType.define do
    name "DateTime"
    coerce_input ->(value) do
      Time.iso8601(value)
    end
    coerce_result ->(value) do
      value.utc.iso8601
    end
  end

  HumanLike = GraphQL::InterfaceType.define do
    name "HumanLike"
    field :updatedAt, !DateTime
  end

  PersonType = GraphQL::ObjectType.define do
    name "Person"
    interfaces [HumanLike]
    field :login, types.String
    field :name, types.String
    field :firstName, types.String
    field :lastName, types.String
    field :company, types.String
    field :homepageURL, types.String
    field :createdAt, !DateTime
    field :hobbies, types[types.String]
  end

  PersonConnection = PersonType.define_connection do
    name "PersonConnection"
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :me, !PersonType do
      resolve ->(_query, _args, _ctx) {
        OpenStruct.new(
          login: "josh",
          name: "Josh",
          firstName: "Joshua",
          lastName: "Peek",
          company: "GitHub",
          createdAt: Time.at(0),
          updatedAt: Time.at(1),
          hobbies: ["soccer", "coding"]
        )
      }
    end

    connection :users, PersonConnection do
      argument :first, types.Int

      resolve ->(_query, _args, _ctx) {
        [
          OpenStruct.new(login: "josh"),
          OpenStruct.new(login: "mislav")
        ]
      }
    end
  end

  Schema = GraphQL::Schema.define(query: QueryType) do
    resolve_type -> (_object, _ctx) { PersonType }
  end

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema, execute: Schema, enforce_collocated_callers: true)
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
    rescue GraphQL::Client::QueryResult::UnimplementedFieldError => e
      assert_equal "undefined field `nickname' on Person type. https://git.io/v1y3m", e.to_s
    end
  end

  def test_no_method_when_field_exists_but_was_not_fetched
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          __typename
        }
      }
    GRAPHQL

    person = @client.query(Temp::Query).data.me

    begin
      person.name
      flunk
    rescue GraphQL::Client::QueryResult::UnfetchedFieldError => e
      assert_equal "unfetched field `name' on Person type. https://git.io/v1y3U\n\nme {\n  __typename\n+ name\n}", e.to_s
    end
  end

  def test_no_method_when_snakecase_field_exists_but_was_not_fetched
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          __typename
        }
      }
    GRAPHQL

    person = @client.query(Temp::Query).data.me

    begin
      person.first_name
      flunk
    rescue GraphQL::Client::QueryResult::UnfetchedFieldError => e
      assert_equal "unfetched field `firstName' on Person type. https://git.io/v1y3U\n\nme {\n  __typename\n+ firstName\n}", e.to_s
    end
  end

  def test_no_method_error_leaked_from_parent
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        __typename
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    begin
      person.name
      flunk
    rescue GraphQL::Client::QueryResult::ImplicitlyFetchedFieldError => e
      assert_equal "implicitly fetched field `name' on Person type. https://git.io/v1yGL\n\n" \
        "fragment TestQueryResult__Temp__Person on Person {\n  __typename\n+ name\n}", e.to_s
    end
  end

  def test_no_method_error_snakecase_field_leaked_from_parent
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        __typename
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          firstName
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL

    person = Temp::Person.new(@client.query(Temp::Query).data.me)

    begin
      person.first_name
      flunk
    rescue GraphQL::Client::QueryResult::ImplicitlyFetchedFieldError => e
      assert_equal "implicitly fetched field `firstName' on Person type. https://git.io/v1yGL\n\n" \
        "fragment TestQueryResult__Temp__Person on Person {\n  __typename\n+ firstName\n}", e.to_s
    end
  end

  def test_no_method_error_leaked_from_child
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

    person = @client.query(Temp::Query).data.me

    begin
      person.name
      flunk
    rescue GraphQL::Client::QueryResult::ImplicitlyFetchedFieldError => e
      assert_equal "implicitly fetched field `name' on Person type. https://git.io/v1yGL" \
        "\n\nme {\n  ...TestQueryResult__Temp__Person\n+ name\n}", e.to_s
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
    assert_equal %w(josh mislav), data.users.edges.map(&:node).map(&:login)
  end

  def test_date_scalar_casting
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          createdAt
          updatedAt
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal "Josh", person.name
    assert_equal Time.at(0), person.created_at
    assert_equal Time.at(1), person.updated_at
  end

  include FooHelper

  def test_source_location
    Temp.const_set :Person, @client.parse(<<-'GRAPHQL')
      fragment on Person {
        name
        company
      }
    GRAPHQL
    assert_equal [__FILE__, __LINE__ - 6], Temp::Person.source_location

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          ...TestQueryResult::Temp::Person
        }
      }
    GRAPHQL
    assert_equal [__FILE__, __LINE__ - 7], Temp::Query.source_location
  end

  def test_non_collocated_caller_error
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

    person = Temp::Person.new(response.data.me)
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Josh works at GitHub", format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal true, person_employed?(person)
    end
  end

  def test_list_of_string_scalar_casting
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          hobbies
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal ["soccer", "coding"], person.hobbies
  end

  def test_empty_selection_existence
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.nil?
    assert_equal "Person", response.data.me.typename
    assert response.data.me.type_of?(:Person)
  end

  def test_empty_selection_existence_with_fragment
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on Query {
        me {
          name
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me
        ...TestQueryResult::Temp::Fragment
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.nil?
    assert_equal "Person", response.data.me.typename
    assert response.data.me.type_of?(:Person)

    person = Temp::Fragment.new(response.data).me
    assert_equal "Josh", person.name
  end
end
