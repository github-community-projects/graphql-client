require "graphql"

module GraphQL
  module Language
    # Public: Document transformations to return a minimal document to represent
    # operation.
    module OperationSlice
      # Public: Return's minimal document to represent operation.
      #
      # Find's target operation and any fragment dependencies and returns a
      # new document with just those definitions.
      #
      # document - The Nodes::Document to find definitions.
      # operation_name - The String name of Nodes::OperationDefinition
      #
      # Returns new Nodes::Document.
      def self.slice(document, operation_name)
        seen = Set.new([operation_name])
        stack = [operation_name]

        until stack.empty?
          name = stack.pop
          names = find_definition_fragment_spreads(document, name)
          seen.merge(names)
          stack.concat(names.to_a)
        end

        Nodes::Document.new(definitions: document.definitions.select { |node| seen.include?(node.name) })
      end

      def self.find_definition_fragment_spreads(document, definition_name)
        definition = document.definitions.find { |node| node.name == definition_name }
        raise "missing definition: #{definition_name}" unless definition
        spreads = Set.new
        visitor = Visitor.new(definition)
        visitor[Nodes::FragmentSpread].enter << -> (node, _parent) do
          spreads << node.name
        end
        visitor.visit
        spreads
      end
    end
  end
end
