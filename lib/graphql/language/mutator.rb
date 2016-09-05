require "graphql"
require "set"

module GraphQL
  module Language
    class Mutator
      def initialize(document)
        @document = document
      end

      def rename_definitions(definitions)
        rename_node = -> (node, parent) {
          node.name = definitions.fetch(node.name, node.name)
        }

        visitor = Visitor.new(@document)
        visitor[Nodes::FragmentDefinition].leave << rename_node
        visitor[Nodes::OperationDefinition].leave << rename_node
        visitor[Nodes::FragmentSpread].leave << rename_node
        visitor.visit

        nil
      end

      def prepend_selection(selection)
        on_selections = -> (node, parent) {
          return if !node.selections.any?
          # TODO: Simplify if AbstractNode#eql? is implemented
          existing_selections = Set.new(node.selections.map { |s| s.respond_to?(:name) ? s.name : nil }.compact)
          selections_to_prepend = [selection].reject { |s| existing_selections.include?(s.name) }
          node.selections = selections_to_prepend + node.selections
        }

        visitor = Visitor.new(@document)
        visitor[Nodes::Field].leave << on_selections
        visitor[Nodes::FragmentDefinition].leave << on_selections
        visitor[Nodes::InlineFragment].leave << on_selections
        visitor[Nodes::OperationDefinition].leave << on_selections
        visitor.visit

        nil
      end
    end
  end
end
