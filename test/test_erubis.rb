require "graphql"
require "graphql/client/erubis"
require "minitest/autorun"

class TestErubis < MiniTest::Test
  def test_ignore_graphql_section
    erubis = GraphQL::Client::Erubis.new <<-ERB
      <%graphql
        query {
          viewer {
            login
          }
        }
      %>
      <%= 42 %>
    ERB

    output_buffer = ActionView::OutputBuffer.new
    erubis.result(binding())
    assert_equal "42", output_buffer.strip
  end
end
