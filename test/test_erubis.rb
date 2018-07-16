# frozen_string_literal: true
require "erubi"
require "erubis"
require "graphql"
require "graphql/client/erubi_enhancer"
require "graphql/client/erubis_enhancer"
require "graphql/client/erubis"
require "graphql/client/view_module"
require "minitest/autorun"

class TestErubis < MiniTest::Test
  class ErubiEngine < Erubi::Engine
    include GraphQL::Client::ErubiEnhancer
  end

  def test_no_graphql_section
    src = <<-ERB
      <%= 42 %>
    ERB
    assert_nil GraphQL::Client::ViewModule.extract_graphql_section(src)
  end

  def test_erubis_graphql_section
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
    # rubocop:disable Security/Eval
    eval(erubis.src, binding, "(erubis)")
    assert_equal "42", output_buffer.strip

    expected_query = <<-ERB
        query {
          viewer {
            login
          }
        }
    ERB

    actual_query, lineno = GraphQL::Client::ViewModule.extract_graphql_section(src)
    assert_equal 2, lineno
    assert_equal expected_query.gsub("        ", "").strip, actual_query.gsub("        ", "").strip
  end

  def test_erubi_graphql_section
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

    engine = ErubiEngine.new(src)
    assert_equal "42", eval(engine.src).strip # rubocop:disable Security/Eval
  end
end
