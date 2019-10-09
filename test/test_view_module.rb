# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/view_module"
require "minitest/autorun"

class TestViewModule < MiniTest::Test
  Root = File.expand_path("..", __FILE__)

  class UserType < GraphQL::Schema::Object
    field :login, String, null: false
  end

  class QueryType < GraphQL::Schema::Object
    field :viewer, UserType, null: false
  end

  class Schema < GraphQL::Schema
    query(QueryType)
    def self.resolve_type(_t, _obj, _ctx)
      raise NotImplementedError
    end
  end

  Client = GraphQL::Client.new(schema: Schema)

  module Views
    extend GraphQL::Client::ViewModule
    self.path = "#{Root}/views"
    self.client = Client
  end

  def test_valid_constant_name
    assert GraphQL::Client::ViewModule.valid_constant_name?("Foo")
    refute GraphQL::Client::ViewModule.valid_constant_name?("404")
  end

  def test_const_missing
    assert_kind_of Module, Views::Users
    assert_equal "#{Root}/views/users", Views::Users.path

    assert_kind_of Module, Views::Users::Show
    assert_equal "#{Root}/views/users/show", Views::Users::Show.path

    assert_kind_of GraphQL::Client::FragmentDefinition, Views::Users::Show::User
    assert_equal(<<-'GRAPHQL'.gsub("      ", "").chomp, Views::Users::Show::User.document.to_query_string)
      fragment TestViewModule__Views__Users__Show__User on User {
        login
      }
    GRAPHQL

    assert_kind_of Module, Views::Users::Profile
    assert_equal "#{Root}/views/users/profile", Views::Users::Profile.path
    assert_kind_of GraphQL::Client::FragmentDefinition, Views::Users::Profile::User

    assert_kind_of Module, Views::Users::Profile::Show::User
    assert_equal "#{Root}/views/users/profile/show", Views::Users::Profile::Show.path
    assert_kind_of GraphQL::Client::FragmentDefinition, Views::Users::Profile::Show::User
  end
end
