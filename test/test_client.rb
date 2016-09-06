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

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserQuery
    assert_equal "TestClient::Temp::UserQuery", Temp::UserQuery.name
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserQuery.definition_node
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_node.name
    assert_equal "query", Temp::UserQuery.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, @client.document_slice(Temp::UserQuery.operation_name).to_query_string)

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

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserQuery
    assert_equal "TestClient::Temp::UserQuery", Temp::UserQuery.name
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserQuery.definition_node
    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.definition_node.name
    assert_equal "query", Temp::UserQuery.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserQuery {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, @client.document_slice(Temp::UserQuery.operation_name).to_query_string)

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

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::UserDocument::GetUser
    assert_equal "TestClient::Temp::UserDocument", Temp::UserDocument.name
    assert_equal "TestClient::Temp::UserDocument::GetUser", Temp::UserDocument::GetUser.name
    assert_equal "TestClient__Temp__UserDocument__GetUser", Temp::UserDocument::GetUser.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::UserDocument::GetUser.definition_node
    assert_equal "TestClient__Temp__UserDocument__GetUser", Temp::UserDocument::GetUser.definition_node.name
    assert_equal "query", Temp::UserDocument::GetUser.definition_node.operation_type

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      query TestClient__Temp__UserDocument__GetUser {
        viewer {
          id
          firstName
          lastName
        }
      }
    GRAPHQL

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, @client.document_slice(Temp::UserDocument::GetUser.operation_name).to_query_string)

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
      mutation TestClient__Temp__LikeMutation {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::LikeMutation
    assert_equal "TestClient::Temp::LikeMutation", Temp::LikeMutation.name
    assert_equal "TestClient__Temp__LikeMutation", Temp::LikeMutation.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::LikeMutation.definition_node
    assert_equal "TestClient__Temp__LikeMutation", Temp::LikeMutation.definition_node.name
    assert_equal "mutation", Temp::LikeMutation.definition_node.operation_type

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, @client.document_slice(Temp::LikeMutation.operation_name).to_query_string)
  end

  def test_client_parse_mutation_document
    Temp.const_set :LikeDocument, @client.parse(<<-'GRAPHQL')
      mutation LikeStory {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    query_string = <<-'GRAPHQL'.gsub(/^      /, "").chomp
      mutation TestClient__Temp__LikeDocument__LikeStory {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::OperationDefinition, Temp::LikeDocument::LikeStory
    assert_equal "TestClient::Temp::LikeDocument", Temp::LikeDocument.name
    assert_equal "TestClient::Temp::LikeDocument::LikeStory", Temp::LikeDocument::LikeStory.name
    assert_equal "TestClient__Temp__LikeDocument__LikeStory", Temp::LikeDocument::LikeStory.definition_name

    assert_kind_of GraphQL::Language::Nodes::OperationDefinition, Temp::LikeDocument::LikeStory.definition_node
    assert_equal "TestClient__Temp__LikeDocument__LikeStory", Temp::LikeDocument::LikeStory.definition_node.name
    assert_equal "mutation", Temp::LikeDocument::LikeStory.definition_node.operation_type

    assert_equal(query_string, @client.document.to_query_string)
    assert_equal(query_string, @client.document_slice(Temp::LikeDocument::LikeStory.operation_name).to_query_string)
  end

  def test_client_parse_anonymous_fragment
    Temp.const_set :UserFragment, @client.parse(<<-'GRAPHQL')
      fragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_kind_of GraphQL::Client::FragmentDefinition, Temp::UserFragment
    assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
    assert_equal "TestClient__Temp__UserFragment", Temp::UserFragment.definition_name

    assert_kind_of GraphQL::Language::Nodes::FragmentDefinition, Temp::UserFragment.definition_node
    assert_equal "TestClient__Temp__UserFragment", Temp::UserFragment.definition_node.name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__UserFragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    user = Temp::UserFragment.new({"id" => 1, "firstName" => "Joshua", "lastName" => "Peek"})
    assert_equal 1, user.id
    assert_equal "Joshua", user.first_name
    assert_equal "Peek", user.last_name

    assert_equal "TestClient::Temp::UserFragment", Temp::UserFragment.name
    assert_equal "TestClient::Temp::UserFragment", user.class.name

    assert_raises GraphQL::Client::ValidationError do
      begin
        @client.validate!
      rescue GraphQL::Client::ValidationError => e
        assert_equal "Fragment TestClient__Temp__UserFragment was defined, but not used", e.message
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
      fragment TestClient__Temp__UserDocument__UserProfile on User {
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
      query TestClient__Temp__UserDocument__NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__UserDocument__FriendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__UserDocument__FriendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ... TestClient__Temp__UserDocument__StandardProfilePic
      }

      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document_slice(Temp::UserDocument::NestedFragments.operation_name).to_query_string)
      query TestClient__Temp__UserDocument__NestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__UserDocument__FriendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__UserDocument__FriendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__FriendFields on User {
        id
        name
        ... TestClient__Temp__UserDocument__StandardProfilePic
      }

      fragment TestClient__Temp__UserDocument__StandardProfilePic on User {
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
      fragment TestClient__Temp__ProfilePictureFragment on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ... TestClient__Temp__ProfilePictureFragment
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document_slice(Temp::UserQuery.operation_name).to_query_string)
      fragment TestClient__Temp__ProfilePictureFragment on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ... TestClient__Temp__ProfilePictureFragment
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__FriendFragment
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
      fragment TestClient__Temp__ProfileFragments__ProfilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__FriendFields on User {
        id
        name
        ... TestClient__Temp__ProfileFragments__ProfilePic
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__ProfileFragments__FriendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__ProfileFragments__FriendFields
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document_slice(Temp::UserQuery.operation_name).to_query_string)
      fragment TestClient__Temp__ProfileFragments__ProfilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__FriendFields on User {
        id
        name
        ... TestClient__Temp__ProfileFragments__ProfilePic
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__ProfileFragments__FriendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__ProfileFragments__FriendFields
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
      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }

      query TestClient__Temp__FriendsQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }

      query TestClient__Temp__MutualFriendsQuery {
        user(id: 4) {
          mutualFriends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document_slice(Temp::FriendsQuery.operation_name).to_query_string)
      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }

      query TestClient__Temp__FriendsQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document_slice(Temp::MutualFriendsQuery.operation_name).to_query_string)
      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }

      query TestClient__Temp__MutualFriendsQuery {
        user(id: 4) {
          mutualFriends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }
    GRAPHQL
  end

  def test_client_parse_query_missing_external_fragment
    assert_raises NameError do
      Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
        query {
          ...TestClient::Temp::MissingFragment
        }
      GRAPHQL
    end
  end

  def test_client_parse_query_external_fragment_is_wrong_type
    Temp.const_set :FooFragment, 42

    assert_raises TypeError do
      Temp.const_set :FooQuery, @client.parse(<<-'GRAPHQL')
        query {
          ...TestClient::Temp::FooFragment
        }
      GRAPHQL
    end
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

    user = Temp::UserFragment.new({"login_url" => "/login", "profileName" => "Josh", "name" => "Josh", "isCool" => true})
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
      "name" => "rails",
      "owner" => {
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name
    refute repo.owner.respond_to?(:login)

    owner = Temp::UserFragment.new(repo.owner)
    assert_equal "josh", owner.login
  end

  def test_client_parse_fragment_spread_with_inline_fragment
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
            ...TestClient::Temp::UserFragment
          }
        }
      }
    GRAPHQL

    repo = Temp::RepositoryFragment.new({
      "name" => "rails",
      "owner" => {
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
      "name" => "rails",
      "owner" => {
        "login" => "josh"
      }
    })
    assert_equal "rails", repo.name
    assert_equal "josh", repo.owner.login

    assert_equal "TestClient::Temp::RepositoryFragment", Temp::RepositoryFragment.name
    assert_equal "TestClient::Temp::RepositoryFragment", repo.class.name
    assert_equal "TestClient::Temp::RepositoryFragment.owner", repo.owner.class.name

    assert_raises TypeError do
      Temp::UserFragment.new(repo.owner)
    end
  end
end
