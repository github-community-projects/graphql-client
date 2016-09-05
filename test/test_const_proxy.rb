require "graphql"
require "graphql/client/const_proxy"
require "minitest/autorun"

class TestConstProxy < MiniTest::Test
  module Temp
  end

  def teardown
    Temp.constants.each do |sym|
      Temp.send(:remove_const, sym)
    end
  end

  Foo = Struct.new(:foo)

  def test_call_initializer_with_name
    bar = GraphQL::Client::ConstProxy.new { |name| Foo.new(name) }
    Temp.const_set(:Bar, bar)

    assert_equal "TestConstProxy::Temp::Bar", Temp::Bar.name
    assert_equal "TestConstProxy::Temp::Bar", Temp::Bar.foo
  end

  def test_call_initializer_with_name
    bar = GraphQL::Client::ConstProxy.new { |name| Foo.new(name) }

    assert_raises(RuntimeError) { bar.name }
    assert_raises(RuntimeError) { bar.foo }
  end
end
