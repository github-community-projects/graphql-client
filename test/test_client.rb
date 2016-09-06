require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClient < MiniTest::Test
  UserType = GraphQL::ObjectType.define do
    name "User"
    field :id, !types.ID
    field :firstName, !types.String
    field :lastName, !types.String
  end

  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :viewer, UserType
  end

  Schema = GraphQL::Schema.new(query: QueryType)

  module Temp
  end

  def setup
    @client = GraphQL::Client.new(schema: Schema)
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  def test_client_parse_anonymous_operation
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query D1 {
        __typename
        viewer {
          __typename
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserQuery.document.to_query_string)

    @client.validate!
  end

  def test_client_parse_anonymous_query
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query D1 {
        __typename
        viewer {
          __typename
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserQuery.document.to_query_string)

    @client.validate!
  end

  def test_client_parse_query_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query GetUser {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query D1 {
        __typename
        viewer {
          __typename
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::UserDocument::GetUser.document.to_query_string)

    @client.validate!
  end

  def test_client_parse_anonymous_mutation
    Temp.const_set :LikeMutation, @client.parse(<<-'GRAPHQL')
      mutation {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation D1 {
        __typename
        likeStory(storyID: 12345) {
          __typename
          story {
            __typename
            likeCount
          }
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::LikeMutation.document.to_query_string)
  end

  def test_client_parse_mutation_document
    Temp.const_set :LikeDocument, @client.parse(<<-'GRAPHQL')
      mutation LikeStory {
        __typename
        likeStory(storyID: 12345) {
          __typename
          story {
            __typename
            likeCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation D1 {
        __typename
        likeStory(storyID: 12345) {
          __typename
          story {
            __typename
            likeCount
          }
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, Temp::LikeDocument::LikeStory.document.to_query_string)
  end

  def test_client_parse_anonymous_fragment
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment D1 on User {
        __typename
        id
        firstName
        lastName
      }
    GRAPHQL

    user = Temp::UserFragment.new({"id" => 1, "firstName" => "Joshua", "lastName" => "Peek"})
    assert_equal 1, user.id
    assert_equal "Joshua", user.first_name
    assert_equal "Peek", user.last_name

    # skip
    # assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
    # assert_equal "TestClient::Temp::UserFragment", user.class.name

    assert_raises GraphQL::Client::ValidationError do
      begin
        @client.validate!
      rescue GraphQL::Client::ValidationError => e
        assert_equal "Fragment D1 was defined, but not used", e.message
        raise e
      end
    end
  end

  def test_client_parse_fragment_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      fragment UserProfile on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment D1 on User {
        __typename
        id
        firstName
        lastName
      }
    GRAPHQL
  end

  def test_client_parse_query_fragment_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ...FriendFields
          }
          mutualFriends(first: 10) {
            ...FriendFields
          }
        }
      }

      fragment FriendFields on User {
        id
        name
        ...StandardProfilePic
      }

      fragment StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      query D1 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D3
      }

      fragment D3 on User {
        __typename
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument::NestedFragments.document.to_query_string)
      query D1 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D3
      }

      fragment D3 on User {
        __typename
        profilePic(size: 50)
      }
    GRAPHQL
  end

  def test_client_parse_query_external_fragments_document
    Temp.const_set :ProfilePictureFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        profilePic(size: 50)
      }
    GRAPHQL

    Temp.const_set :FriendFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        name
        ...TestClient::Temp::ProfilePictureFragment
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment D1 on User {
        __typename
        profilePic(size: 50)
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D1
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      fragment D1 on User {
        __typename
        profilePic(size: 50)
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D1
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }
    GRAPHQL
  end

  def test_client_parse_query_external_document_fragment
    Temp.const_set :ProfileFragments, @client.parse(<<-'GRAPHQL')
      fragment ProfilePic on User {
        profilePic(size: 50)
      }

      fragment FriendFields on User {
        id
        name
        ...ProfilePic
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::ProfileFragments::FriendFields
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::ProfileFragments::FriendFields
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment D1 on User {
        __typename
        profilePic(size: 50)
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D1
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      fragment D1 on User {
        __typename
        profilePic(size: 50)
      }

      fragment D2 on User {
        __typename
        id
        name
        ... D1
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D2
          }
          mutualFriends(first: 10) {
            __typename
            ... D2
          }
        }
      }
    GRAPHQL
  end

  def test_client_parse_multiple_queries
    Temp.const_set :FriendFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        name
      }
    GRAPHQL

    Temp.const_set :FriendsQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    Temp.const_set :MutualFriendsQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          mutualFriends(first: 10) {
            ...TestClient::Temp::FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment D1 on User {
        __typename
        id
        name
      }

      query D2 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D1
          }
        }
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          mutualFriends(first: 10) {
            __typename
            ... D1
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::FriendsQuery.document.to_query_string)
      fragment D1 on User {
        __typename
        id
        name
      }

      query D2 {
        __typename
        user(id: 4) {
          __typename
          friends(first: 10) {
            __typename
            ... D1
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::MutualFriendsQuery.document.to_query_string)
      fragment D1 on User {
        __typename
        id
        name
      }

      query D3 {
        __typename
        user(id: 4) {
          __typename
          mutualFriends(first: 10) {
            __typename
            ... D1
          }
        }
      }
    GRAPHQL
  end

  def test_client_parse_fragment_query_result_aliases
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login_url
        profileName
        name: profileName
        isCool
      }
    GRAPHQL

    user = Temp::UserFragment.new({"__typename" => "User", "login_url" => "/login", "profileName" => "Josh", "name" => "Josh", "isCool" => true})
    assert_equal "/login", user.login_url
    assert_equal "Josh", user.profile_name
    assert_equal "Josh", user.name
    assert user.is_cool?
  end

  def test_client_parse_fragment_query_result_with_nested_fields
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

    user = Temp::UserFragment.new({
      "id" => "1",
      "repositories" => [
        {
          "name" => "github",
          "watchers" => {
            "login" => "josh"
          }
        }
      ]
    })

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers.login
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

    user = Temp::UserFragment.new({
      "id" => "1",
      "repositories" => [
        {
          "name" => "github",
          "watchers" => {
            "login" => "josh"
          }
        }
      ]
    })

    assert_equal "1", user.id
    assert_kind_of Array, user.repositories
    assert_equal "github", user.repositories[0].name
    assert_equal "josh", user.repositories[0].watchers.login
  end

  def test_client_parse_nested_inline_fragments_on_same_node
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

    user = Temp::UserFragment.new({
      "__typename" => "User",
      "id" => "1",
      "login" => "josh",
      "password" => "secret"
    })

    assert_equal "1", user.id
    assert_equal "josh", user.login
    assert_equal "secret", user.password
  end

  def test_client_parse_fragment_spread_constant
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        login
      }
    GRAPHQL

    Temp.const_set :RepositoryFragment, @client.parse(<<-'GRAPHQL')
      fragment on Repository {
        name
        owner {
          ...TestClient::Temp::UserFragment
        }
      }
    GRAPHQL

    repo = Temp::RepositoryFragment.new({
      "__typename" => "Repository",
      "name" => "rails",
      "owner" => {
        "__typename" => "User",
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_client_parse_invalid_fragment_cast
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

    repo = Temp::RepositoryFragment.new({
      "__typename" => "Repository",
      "name" => "rails",
      "owner" => {
        "__typename" => "User",
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name
    assert_equal "josh", repo.owner.login

    # skip
    # assert_equal "TestClient::Temp::RepositoryFragment", Temp::RepositoryFragment.name
    # assert_equal "TestClient::Temp::RepositoryFragment", repo.class.name
    # assert_equal "TestClient::Temp::RepositoryFragment.owner", repo.owner.class.name

    assert_raises TypeError do
      Temp::UserFragment.new(repo.owner)
    end
  end
end
