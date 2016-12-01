# frozen_string_literal: true
require "graphql/client/collocated_enforcement"
require "minitest/autorun"
require_relative "foo_helper"

class TestCollocatedEnforcement < MiniTest::Test
  include FooHelper

  class Person
    extend GraphQL::Client::CollocatedEnforcement

    def name
      "Josh"
    end

    def company
      "GitHub"
    end

    def company?
      true
    end

    enforce_collocated_callers(self, %w(name company company?), __FILE__)
  end

  def test_deep_freeze
    assert_raises GraphQL::Client::NonCollocatedCallerError do
      format_person_info(Person.new)
    end

    assert_raises GraphQL::Client::NonCollocatedCallerError do
      person_employed?(Person.new)
    end
  end
end
