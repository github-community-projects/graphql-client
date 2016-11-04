require "rubocop/cop/graphql/heredoc"
require "minitest/autorun"

class TestRubocopHeredoc < MiniTest::Test
  def setup
    config = RuboCop::Config.new
    @cop = RuboCop::Cop::GraphQL::Heredoc.new(config)
  end

  def test_good_graphql_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-'GRAPHQL'
        { version }
      GRAPHQL
    RUBY

    assert_empty @cop.offenses.map(&:message)
  end

  def test_bad_graphql_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-GRAPHQL
        { version }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses.first.message
  end

  def test_bad_graphql_multiline_heredoc
    investigate(@cop, <<-RUBY)
      Query = Client.parse <<-GRAPHQL
        {
          version
        }
      GRAPHQL
    RUBY

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL heredocs should be quoted. <<-'GRAPHQL'", @cop.offenses.first.message
  end


  private

  def investigate(cop, src)
    processed_source = RuboCop::ProcessedSource.new(src, RUBY_VERSION.to_f)
    commissioner = RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)
    commissioner.investigate(processed_source)
    commissioner
  end
end
