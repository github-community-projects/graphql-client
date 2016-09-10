require "graphql"
require "graphql/client/erubis"
require "minitest/autorun"

class TestErubis < MiniTest::Test
  def test_no_graphql_section
    src = <<-ERB
      <%= 42 %>
    ERB
    assert_equal nil, GraphQL::Client::Erubis.extract_graphql_sections(src)
  end

  def test_graphql_section
    src = <<-ERB
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
    erubis.result(binding())
    assert_equal "42", output_buffer.strip

    query = <<-ERB
        query {
          viewer {
            login
          }
        }
    ERB

    assert_equal query.gsub("        ", "").strip,
      GraphQL::Client::Erubis.extract_graphql_sections(src).gsub("        ", "").strip
  end
end
