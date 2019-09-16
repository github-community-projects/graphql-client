# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "minitest/autorun"
require "time" # required for Time#iso8601
require "ostruct"
require_relative "foo_helper"

class TestQueryResult < MiniTest::Test
  class DateTimeType < GraphQL::Schema::Scalar
    def self.coerce_input(value, ctx)
      Time.iso8601(value)
    end

    def self.coerce_result(value, ctx)
      value.utc.iso8601
    end
  end

  module NodeType
    include GraphQL::Schema::Interface
    field :id, ID, null: false
  end

  class PlanType < GraphQL::Schema::Enum
    value("FREE")
    value("SMALL")
    value("LARGE")
  end

  module AdminUser
    include GraphQL::Schema::Interface
    field :password, String, null: false
  end

  class RepositoryType < GraphQL::Schema::Object
    field :name, String, null: false
    field :owner, "TestQueryResult::UserType", null: false
    field :star_count, Integer, null: false
    field :watchers, "[TestQueryResult::UserType]", null: false
  end

  class UserType < GraphQL::Schema::Object
    implements NodeType, AdminUser
    field :id, ID, null: false
    field :first_name, String, null: false
    field :last_name, String, null: false
    field :name, String, null: false
    field :login, String, null: false
    field :login_url, String, null: false
    field :profile_name, String, null: false
    field :is_cool, Boolean, null: false
    field :profile_pic, String, null: true do
      argument :size, Integer, required: false
    end
    field :repositories, [RepositoryType], null: false
  end

  module HumanLike
    include GraphQL::Schema::Interface
    field :updated_at, DateTimeType, null: false
  end

  class PersonType < GraphQL::Schema::Object
    implements HumanLike
    field :login, String, null: true
    field :name, String, null: true
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :company, String, null: true
    field :homepageURL, String, null: true
    field :created_at, DateTimeType, null: false
    field :hobbies, [String], null: true
    field :plan, PlanType, null: false
  end

  class IssueType < GraphQL::Schema::Object
    field :title, String, null: false
    field :assignees, [UserType], null: false
  end

  class PullRequestType < GraphQL::Schema::Object
    field :title, String, null: false
    field :assignees, [UserType], null: false
  end

  class OrganizationType < GraphQL::Schema::Object
    implements NodeType
    field :name, String, null: false
  end

  class BotType < GraphQL::Schema::Object
    field :login, String, null: true
  end

  class IssueOrPullRequest < GraphQL::Schema::Union
    possible_types IssueType, PullRequestType
  end

  class Actor < GraphQL::Schema::Union
    possible_types PersonType, BotType
  end

  PersonConnection = PersonType.connection_type

  class QueryType < GraphQL::Schema::Object
    field :me, PersonType, null: false
    def me
      OpenStruct.new(
        login: "josh",
        name: "Josh",
        first_name: "Joshua",
        last_name: "Peek",
        company: "GitHub",
        created_at: Time.at(0),
        updated_at: Time.at(1),
        hobbies: ["soccer", "coding"],
        homepage_url: nil,
        plan: "LARGE"
      )
    end

    field :issue_or_pull_request, IssueOrPullRequest, null: false
    def issue_or_pull_request
      OpenStruct.new({
        type: PullRequestType,
        title: "Some issue",
        assignees: [
          OpenStruct.new(
            login: "josh",
            name: "Josh",
            first_name: "Joshua",
            last_name: "Peek",
            company: "GitHub",
            created_at: Time.at(0),
            updated_at: Time.at(1),
            hobbies: ["soccer", "coding"],
            plan: "LARGE"
          )
        ]
      })
    end

    field :user_no_hobbies, PersonType, null: false
    def user_no_hobbies
      OpenStruct.new(
        hobbies: nil
      )
    end

    field :current_actor, Actor, null: false
    def current_actor
      OpenStruct.new(
        type: PersonType,
        login: "josh",
        name: "Josh",
        first_name: "Joshua",
        last_name: "Peek",
        updated_at: Time.at(1),
      )
    end

    field :users, PersonConnection, null: true do
      argument :first, Integer, required: false
    end

    def users
      [
        OpenStruct.new(login: "josh"),
        OpenStruct.new(login: "mislav")
      ]
    end

    field :node, NodeType, null: true do
      argument :id, ID, required: true
    end

    def node(id:)
      {
        "1" => OpenStruct.new({
          type: UserType,
          id: "1",
          login: "josh",
          password: "secret",
          login_url: "/login",
          profile_name: "Josh",
          is_cool: true,
          repositories: [
            OpenStruct.new(
              type: RepositoryType,
              name: "github",
              watchers: [
                OpenStruct.new(login: "josh")
              ]
            )
          ]
        })
      }[id]
    end

    field :user, UserType, null: true do
      argument :id, ID, required: true
    end

    field :organization, OrganizationType, null: true do
      argument :id, ID, required: true
    end

    field :repository, RepositoryType, null: true
    def repository
      OpenStruct.new({
        name: "rails",
        owner: OpenStruct.new(type: UserType, login: "josh")
      })
    end
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
    raw_result = {"firstName"=>"Joshua", "lastName"=>"Peek"}
    assert_equal raw_result, person.to_h

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

  def test_field_aliases
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
    rescue GraphQL::Client::UnimplementedFieldError => e
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

    assert_raises GraphQL::Client::UnfetchedFieldError, "unfetched field `name' on Person type. https://git.io/v1y3U" do
      person.name
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

    assert_raises GraphQL::Client::UnfetchedFieldError, "unfetched field `firstName' on Person type. https://git.io/v1y3U" do
      person.first_name
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

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `name' on Person type. https://git.io/v1yGL" do
      person.name
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

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `firstName' on Person type. https://git.io/v1yGL" do
      person.first_name
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

    assert_raises GraphQL::Client::ImplicitlyFetchedFieldError, "implicitly fetched field `name' on Person type. https://git.io/v1yGL" do
      person.name
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

  def test_enum_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me {
          name
          plan
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.me
    assert_equal "Josh", person.name
    assert_equal "LARGE", person.plan
  end

  def test_union_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        currentActor {
          ... on Person {
            login
          }
          ... on Bot {
            login
          }
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    actor = response.data.current_actor
    assert_equal "Person", actor.class.type.graphql_name
    assert_equal "josh", actor.login
  end

  def test_interface_within_union_values
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        currentActor {
          ... on Person {
            login
          }
          ... on HumanLike {
            updatedAt
          }
          ... on Person {
            name
          }
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    actor = response.data.current_actor
    assert_equal "Person", actor.class.type.graphql_name
    assert_equal "josh", actor.login
    assert_equal "Josh", actor.name
    assert_equal Time.at(1).utc, actor.updated_at
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

    response = @client.query(Temp::Query)

    person = Temp::Person.new(response.data.me)
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Josh works at GitHub", format_person_info(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal true, person_employed?(person)
    end

    GraphQL::Client.allow_noncollocated_callers do
      assert_equal "Joshua Peek", format_person_name(person)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_name(person)
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

  def test_nullable_list
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        userNoHobbies {
          hobbies
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    person = response.data.user_no_hobbies
    assert_nil person.hobbies
  end

  def test_empty_selection_existence
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        me
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    refute response.data.me.nil?
    assert_equal "Person", response.data.me.class.type.graphql_name
    assert response.data.me.is_a?(@client.types::Person)
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
    assert_kind_of @client.types::Person, response.data.me
    assert_equal "Person", response.data.me.class.type.graphql_name
    assert response.data.me.is_a?(@client.types::Person)

    person = Temp::Fragment.new(response.data).me
    assert_equal "Josh", person.name
  end

  def test_parse_fragment_query_result_with_nested_fields
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        repositories {
          name
          watchers {
            login
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_parse_fragment_spread_constant
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)

    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_parse_nested_inline_fragments_on_same_node
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on Node {
        id
        ... on User {
          login
          ... on AdminUser {
            password
          }
        }
        ... on Organization {
          name
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_equal "josh", user.login
    assert_equal "secret", user.password
  end

  def test_parse_fragment_query_result_aliases
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        loginUrl
        profileName
        name: profileName
        isCool
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "/login", user.login_url
    assert_equal "Josh", user.profile_name
    assert_equal "Josh", user.name
    assert user.is_cool?
  end

  def test_parse_fragment_spread_with_inline_fragment
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ... on User {
            ...TestQueryResult::Temp::UserFragment
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login

    owner = Temp::UserFragment.new(owner)
    assert_equal "josh", owner.login
  end

  def test_parse_fragment_spread_with_local_fragment
    Temp.const_set :Queries, @client.parse(<<-'GRAPHQL')
      fragment RepositoryFragment on Repository {
        name
      }

      query Query {
        repository {
          ...RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Queries::Query)
    assert_equal "rails", response.data.repository.name
  end

  def test_supports_unions_with_array_fields
    Temp.const_set :Fragment, @client.parse(<<-'GRAPHQL')
      fragment on IssueOrPullRequest {
        ... on PullRequest {
          assignees {
            login
          }
        }

        ... on Issue {
          assignees {
            login
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        issueOrPullRequest {
          ...TestQueryResult::Temp::Fragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    obj = Temp::Fragment.new(response.data.issue_or_pull_request)

    assert_equal 1, obj.assignees.size
    assert_equal "josh", obj.assignees[0].login
  end

  def test_parse_invalid_fragment_cast
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          login
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        repository {
          ...TestQueryResult::Temp::RepositoryFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    repo = Temp::RepositoryFragment.new(response.data.repository)

    assert_equal "rails", repo.name
    assert_equal "josh", repo.owner.login

    assert_raises TypeError,  "TestQueryResult::Temp::UserFragment is not included in TestQueryResult::Temp::RepositoryFragment" do
      Temp::UserFragment.new(repo.owner)
    end
  end

  def test_parse_invalid_fragment_cast_on_spread
    Temp.const_set :AdminFragment, @client.parse(<<-'GRAPHQL')
      fragment on AdminUser {
        password
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          id
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    assert_raises TypeError, "TestQueryResult::Temp::AdminFragment is not included in TestQueryResult::Temp::Query" do
      Temp::AdminFragment.new(response.data.node)
    end
  end

  def test_parse_valid_fragment_cast_on_spread
    Temp.const_set :AdminFragment, @client.parse(<<-'GRAPHQL')
      fragment on AdminUser {
        password
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::AdminFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)
    admin = Temp::AdminFragment.new(response.data.node)

    assert_equal "secret", admin.password
  end

  def test_client_parse_fragment_query_result_with_inline_fragments
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        repositories {
          ... on Repository {
            name
            watchers {
              ... on User {
                login
              }
            }
          }
        }
      }
    GRAPHQL

    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ...TestQueryResult::Temp::UserFragment
        }
      }
    GRAPHQL

    response = @client.query(Temp::Query)

    user = Temp::UserFragment.new(response.data.node)

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers[0].login
  end

  def test_client_query_result_with_include_and_skip_directives
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      query($includeId: Boolean!, $skipRepositories: Boolean!) {
        node(id: "1") {
          ... on User {
            id @include(if: $includeId)
            repositories @skip(if: $skipRepositories) {
              name
            }
          }
        }
      }
    GRAPHQL

    assert response = @client.query(Temp::Query, variables: { includeId: true, skipRepositories: false })
    assert user = response.data.node
    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name

    assert response = @client.query(Temp::Query, variables: { includeId: false, skipRepositories: false })
    assert user = response.data.node
    assert_nil user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name

    assert response = @client.query(Temp::Query, variables: { includeId: true, skipRepositories: true })
    assert user = response.data.node
    assert_equal "1", user.id
    assert_nil user.repositories

    assert response = @client.query(Temp::Query, variables: { includeId: false, skipRepositories: true })
    assert user = response.data.node
    assert_nil user.id
    assert_nil user.repositories
  end

  def test_client_query_result_with_type_mismatch
    Temp.const_set :Query, @client.parse(<<-'GRAPHQL')
      {
        node(id: "1") {
          ... on Organization {
            id
          }
        }
      }
    GRAPHQL

    assert response = @client.query(Temp::Query)
    assert user = response.data.node
    assert_kind_of @client.types::User, user
  end
end
