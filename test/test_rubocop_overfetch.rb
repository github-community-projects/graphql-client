# frozen_string_literal: true
require "graphql/client/erubis"
require "rubocop/cop/graphql/overfetch"
require "minitest/autorun"

class TestRubocopOverfetch < MiniTest::Test
  Root = File.expand_path("..", __FILE__)

  def setup
    config = RuboCop::Config.new
    @cop = RuboCop::Cop::GraphQL::Overfetch.new(config)
  end

  def test_all_fields_used
    investigate(@cop, "#{Root}/views/users/show.html.erb")

    assert_empty @cop.offenses.map(&:message)
  end

  def test_field_unused
    investigate(@cop, "#{Root}/views/users/overfetch.html.erb")

    assert_equal 1, @cop.offenses.count
    assert_equal "GraphQL field 'birthday' query but was not used in template.", @cop.offenses.first.message
  end

  private

  def investigate(cop, path)
    engine = GraphQL::Client::Erubis.new(File.read(path))
    processed_source = RuboCop::ProcessedSource.new(engine.src, RUBY_VERSION.to_f, path)
    commissioner = RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)
    commissioner.investigate(processed_source)
    commissioner
  end
end
