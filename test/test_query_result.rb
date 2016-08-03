require "graphql"
require "graphql/query_result"
require "minitest/autorun"

class TestQueryResult < MiniTest::Test
  def test_define_simple_query_result
    fields = {
      "name" => nil,
      "company" => nil
    }
    person_klass = GraphQL::QueryResult.define(fields: fields)

    person = person_klass.new({"name" => "Josh", "company" => "GitHub"})
    assert_equal "Josh", person.name
    assert_equal "GitHub", person.company
  end

  def test_snakecase_field_aliases
    fields = {
      "firstName" => nil,
      "lastName" => nil
    }
    person_klass = GraphQL::QueryResult.define(fields: fields)

    person = person_klass.new({"firstName" => "Joshua", "lastName" => "Peek"})
    assert_equal "Joshua", person.first_name
    assert_equal "Peek", person.last_name
  end

  def test_predicate_aliases
    fields = {
      "name" => nil,
      "company" => nil
    }
    person_klass = GraphQL::QueryResult.define(fields: fields)

    person = person_klass.new({"name" => "Josh", "company" => nil})
    assert_equal true, person.name?
    assert_equal false, person.company?
  end
end
