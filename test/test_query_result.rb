require "graphql"
require "graphql/client/query_result"
require "minitest/autorun"

class TestQueryResult < MiniTest::Test
  def test_define_simple_query_result
    fields = {
      "name" => nil,
      "company" => nil
    }
    person_klass = GraphQL::Client::QueryResult.define(fields: fields)

    person = person_klass.new({"name" => "Josh", "company" => "GitHub"})
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_snakecase_field_aliases
    fields = {
      "firstName" => nil,
      "lastName" => nil
    }
    person_klass = GraphQL::Client::QueryResult.define(fields: fields)

    person = person_klass.new({"firstName" => "Joshua", "lastName" => "Peek"})
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
  end

  def test_predicate_aliases
    fields = {
      "name" => nil,
      "company" => nil
    }
    person_klass = GraphQL::Client::QueryResult.define(fields: fields)

    person = person_klass.new({"name" => "Josh", "company" => nil})
    assert_equal true, person.name?
    assert_equal false, person.company?
  end

  def test_no_method_error
    person_klass = GraphQL::Client::QueryResult.define(fields: {"fullName" => nil})
    person = person_klass.new({"fullName" => "Joshua Peek"})

    begin
      person.name
      flunk
    rescue NoMethodError => e
      assert_equal "undefined method `name' for #<GraphQL::Client::QueryResult fullName=\"Joshua Peek\">", e.to_s
    end
  end

  Person = GraphQL::Client::QueryResult.define(fields: {"fullName" => nil})

  def test_no_method_error_constant
    person = Person.new({"fullName" => "Joshua Peek"})

    begin
      person.name
      flunk
    rescue NoMethodError => e
      assert_equal "undefined method `name' for #<TestQueryResult::Person fullName=\"Joshua Peek\">", e.to_s
    end
  end

  def test_merge_classes
    person1_klass = GraphQL::Client::QueryResult.define(fields: { "name" => nil, "company" => nil })
    person2_klass = GraphQL::Client::QueryResult.define(fields: { "name" => nil, "login" => nil })
    person3_klass = person1_klass | person2_klass
    assert_equal [:name, :company, :login], person3_klass.fields.keys
  end

  def test_merge_nested_classes
    person1_klass = GraphQL::Client::QueryResult.define(fields: { "name" => nil, "company" => nil })
    person2_klass = GraphQL::Client::QueryResult.define(fields: { "name" => nil, "login" => nil })

    root1_klass = GraphQL::Client::QueryResult.define(fields: { "viewer" => person1_klass })
    root2_klass = GraphQL::Client::QueryResult.define(fields: { "viewer" => person2_klass })
    root3_klass = root1_klass | root2_klass

    assert_equal [:name, :company, :login], root3_klass.fields[:viewer].fields.keys
  end
end
