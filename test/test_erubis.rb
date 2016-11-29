# frozen_string_literal: true
require "graphql"
require "graphql/client/erubis"
require "minitest/autorun"

class TestErubis < MiniTest::Test
  def test_no_graphql_section
    src = <<-ERB
      <%= 42 %>
    ERB
    assert_equal nil, GraphQL::Client::Erubis.extract_graphql_section(src)
  end

  def test_graphql_section
    src = <<-ERB
      <%# Some comment %>
      <%graphql
        query {
          viewer {
            login
          }
        }
      %>
      <%= 42 %>
    ERB

    erubis = GraphQL::Client::Erubis.new(src)

    output_buffer = ActionView::OutputBuffer.new
    erubis.result(binding)
    assert_equal "42", output_buffer.strip

    expected_query = <<-ERB
        query {
          viewer {
            login
          }
        }
    ERB

    actual_query, lineno = GraphQL::Client::Erubis.extract_graphql_section(src)
    assert_equal 2, lineno
    assert_equal expected_query.gsub("        ", "").strip, actual_query.gsub("        ", "").strip
  end
end
