require "graphql"
require "set"

module GraphQL
  module Language
    class Mutator
      def initialize(document)
        @document = document
      end

      def prepend_selection(selection)
        visitor = Visitor.new(@document)

        on_selections = -> (node, parent) {
          return if !node.selections.any?
          # TODO: Simplify if AbstractNode#eql? is implemented
          existing_selections = Set.new(node.selections.map { |s| s.respond_to?(:name) ? s.name : nil }.compact)
          selections_to_prepend = [selection].reject { |s| existing_selections.include?(s.name) }
          node.selections = selections_to_prepend + node.selections
        }

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
