require "graphql"

module GraphQL
  module Language
    module Nodes
      # Public: Define shared trait for Nodes that have a "selections" collection.
      module Selections
      end

      # Public: Define shared trait for Nodes that may be in a "selections" collection.
      module Selection
      end

      class Field < AbstractNode
        include Selection
        include Selections
      end

      class FragmentDefinition < AbstractNode
        include Selections
      end

      class FragmentSpread < AbstractNode
        include Selection
      end

      class InlineFragment < AbstractNode
        include Selection
        include Selections
      end

      class OperationDefinition < AbstractNode
        include Selections
      end
    end
  end
end
