require "graphql"
require "graphql/language/nodes/selection_ext"
require "minitest/autorun"

class TestSelectionExt < MiniTest::Test
  def test_are_a_selection
    assert GraphQL::Language::Nodes::Field < GraphQL::Language::Nodes::Selection
    assert GraphQL::Language::Nodes::FragmentSpread < GraphQL::Language::Nodes::Selection
    assert GraphQL::Language::Nodes::InlineFragment < GraphQL::Language::Nodes::Selection
  end

  def test_has_selections
    assert GraphQL::Language::Nodes::Field < GraphQL::Language::Nodes::Selections
    assert GraphQL::Language::Nodes::FragmentDefinition < GraphQL::Language::Nodes::Selections
    assert GraphQL::Language::Nodes::InlineFragment < GraphQL::Language::Nodes::Selections
    assert GraphQL::Language::Nodes::OperationDefinition < GraphQL::Language::Nodes::Selections
  end
end
