require "graphql"

module GraphQL
  module Language
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
        definitions = []
        definitions << document.definitions.find { |d| d.name == operation_name }

        visitor = Visitor.new(document)
        visitor[Nodes::FragmentSpread] << -> (node, parent) {
          if fragment = document.definitions.find { |d| d.name == node.name }
            definitions << fragment
          end
        }
        visitor.visit

        Nodes::Document.new(definitions: definitions.uniq)
      end
    end
  end
end
