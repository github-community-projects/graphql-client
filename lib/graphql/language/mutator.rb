require "graphql"
require "set"

module GraphQL
  module Language
    class Mutator
      def initialize(document)
        @document = document
      end

      module LazyName
        def name
          @name.call
        end
      end

      def rename_definitions(definitions)
        rename_node = -> (node, parent) {
          if name = definitions[node.name]
            node.extend(LazyName) if name.is_a?(Proc)
            node.name = name
          end
        }

        visitor = Visitor.new(@document)
        visitor[Nodes::FragmentDefinition].leave << rename_node
        visitor[Nodes::OperationDefinition].leave << rename_node
        visitor[Nodes::FragmentSpread].leave << rename_node
        visitor.visit

        nil
      end
    end
  end
end
