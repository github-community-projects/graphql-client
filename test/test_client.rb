require "graphql"
require "graphql/client"
require "json"
require "minitest/autorun"

class TestClient < MiniTest::Test
  json = File.read(File.expand_path("../swapi-schema.json", __FILE__))
  Schema = GraphQL::Schema::Loader.load(JSON.parse(json))

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
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      query TestClient__Temp__UserQuery {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        id
        firstName
        lastName
      }
    GRAPHQL
  end

  def test_client_parse_anonymous_query
    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      query TestClient__Temp__UserQuery {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        id
        firstName
        lastName
      }
    GRAPHQL
  end

  def test_client_parse_query_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query getUser {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      query TestClient__Temp__UserDocument__getUser {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal "TestClient__Temp__UserDocument__getUser", Temp::UserDocument.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument.document.to_query_string)
      query TestClient__Temp__UserDocument__getUser {
        id
        firstName
        lastName
      }
    GRAPHQL
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

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      mutation TestClient__Temp__LikeMutation {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    assert_equal "TestClient__Temp__LikeMutation", Temp::LikeMutation.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::LikeMutation.document.to_query_string)
      mutation TestClient__Temp__LikeMutation {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL
  end

  def test_client_parse_mutation_document
    Temp.const_set :LikeDocument, @client.parse(<<-'GRAPHQL')
      mutation likeStory {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      mutation TestClient__Temp__LikeDocument__likeStory {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL

    assert_equal "TestClient__Temp__LikeDocument__likeStory", Temp::LikeDocument.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::LikeDocument.document.to_query_string)
      mutation TestClient__Temp__LikeDocument__likeStory {
        likeStory(storyID: 12345) {
          story {
            likeCount
          }
        }
      }
    GRAPHQL
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
      fragment TestClient__Temp__UserFragment on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal nil, Temp::UserFragment.operation_name
  end

  def test_client_parse_fragment_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      fragment userProfile on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__UserDocument__userProfile on User {
        id
        firstName
        lastName
      }
    GRAPHQL

    assert_equal nil, Temp::UserDocument.operation_name
  end

  def test_client_parse_query_fragment_document
    Temp.const_set :UserDocument, @client.parse(<<-'GRAPHQL')
      query withNestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ...friendFields
          }
          mutualFriends(first: 10) {
            ...friendFields
          }
        }
      }

      fragment friendFields on User {
        id
        name
        ...standardProfilePic
      }

      fragment standardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      query TestClient__Temp__UserDocument__withNestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__UserDocument__friendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__UserDocument__friendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__friendFields on User {
        id
        name
        ... TestClient__Temp__UserDocument__standardProfilePic
      }

      fragment TestClient__Temp__UserDocument__standardProfilePic on User {
        profilePic(size: 50)
      }
    GRAPHQL

    assert_equal "TestClient__Temp__UserDocument__withNestedFragments", Temp::UserDocument.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserDocument.document.to_query_string)
      query TestClient__Temp__UserDocument__withNestedFragments {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__UserDocument__friendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__UserDocument__friendFields
          }
        }
      }

      fragment TestClient__Temp__UserDocument__friendFields on User {
        id
        name
        ... TestClient__Temp__UserDocument__standardProfilePic
      }

      fragment TestClient__Temp__UserDocument__standardProfilePic on User {
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

    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.operation_name
    assert_equal nil, Temp::FriendFragment.operation_name
    assert_equal nil, Temp::ProfilePictureFragment.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
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

      fragment TestClient__Temp__ProfilePictureFragment on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
        ... TestClient__Temp__ProfilePictureFragment
      }
    GRAPHQL
  end

  def test_client_parse_query_external_document_fragment
    Temp.const_set :ProfileFragments, @client.parse(<<-'GRAPHQL')
      fragment profilePic on User {
        profilePic(size: 50)
      }

      fragment friendFields on User {
        id
        name
        ...profilePic
      }
    GRAPHQL

    Temp.const_set :UserQuery, @client.parse(<<-'GRAPHQL')
      query {
        user(id: 4) {
          friends(first: 10) {
            ...TestClient::Temp::ProfileFragments.friendFields
          }
          mutualFriends(first: 10) {
            ...TestClient::Temp::ProfileFragments.friendFields
          }
        }
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, @client.document.to_query_string)
      fragment TestClient__Temp__ProfileFragments__profilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__friendFields on User {
        id
        name
        ... TestClient__Temp__ProfileFragments__profilePic
      }

      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__ProfileFragments__friendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__ProfileFragments__friendFields
          }
        }
      }
    GRAPHQL

    assert_equal "TestClient__Temp__UserQuery", Temp::UserQuery.operation_name
    assert_equal nil, Temp::ProfileFragments.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::UserQuery.document.to_query_string)
      query TestClient__Temp__UserQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__ProfileFragments__friendFields
          }
          mutualFriends(first: 10) {
            ... TestClient__Temp__ProfileFragments__friendFields
          }
        }
      }

      fragment TestClient__Temp__ProfileFragments__profilePic on User {
        profilePic(size: 50)
      }

      fragment TestClient__Temp__ProfileFragments__friendFields on User {
        id
        name
        ... TestClient__Temp__ProfileFragments__profilePic
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

    assert_equal nil, Temp::FriendFragment.operation_name
    assert_equal "TestClient__Temp__FriendsQuery", Temp::FriendsQuery.operation_name
    assert_equal "TestClient__Temp__MutualFriendsQuery", Temp::MutualFriendsQuery.operation_name

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::FriendsQuery.document.to_query_string)
      query TestClient__Temp__FriendsQuery {
        user(id: 4) {
          friends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }
    GRAPHQL

    assert_equal(<<-'GRAPHQL'.gsub(/^      /, "").chomp, Temp::MutualFriendsQuery.document.to_query_string)
      query TestClient__Temp__MutualFriendsQuery {
        user(id: 4) {
          mutualFriends(first: 10) {
            ... TestClient__Temp__FriendFragment
          }
        }
      }

      fragment TestClient__Temp__FriendFragment on User {
        id
        name
      }
    GRAPHQL
  end
end
