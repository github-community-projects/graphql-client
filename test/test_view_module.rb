# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/view_module"
require "minitest/autorun"

class TestViewModule < MiniTest::Test
  Root = File.expand_path("..", __FILE__)
  Client = GraphQL::Client.new

  module Views
    extend GraphQL::Client::ViewModule
    self.path = "#{Root}/views"
    self.client = Client
  end

  def test_valid_constant_name
    assert GraphQL::Client::ViewModule.valid_constant_name?("Foo")
    refute GraphQL::Client::ViewModule.valid_constant_name?("404")
  end

  def test_const_path
    assert_equal "#{Root}/views/users", Views.const_path(:Users)
    assert_equal "#{Root}/views/users/show.html.erb", Views::Users.const_path(:Show)
    assert_equal "#{Root}/views/users/_profile.html.erb", Views::Users.const_path(:Profile)

    assert_equal nil, Views.const_path(:Missing)
  end

  def test_const_missing
    assert_kind_of Module, Views::Users
    assert_equal "#{Root}/views/users", Views::Users.path

    assert_kind_of Module, Views::Users::Show
    assert_equal "#{Root}/views/users/show.html.erb", Views::Users::Show.path

    assert_kind_of GraphQL::Client::FragmentDefinition, Views::Users::Show::User
    assert_equal(<<-'GRAPHQL'.gsub("      ", "").chomp, Views::Users::Show::User.document.to_query_string)
      fragment TestViewModule__Views__Users__Show__User on User {
        login
      }
    GRAPHQL

    assert_kind_of Module, Views::Users::Profile
    assert_equal "#{Root}/views/users/_profile.html.erb", Views::Users::Profile.path
  end
end
