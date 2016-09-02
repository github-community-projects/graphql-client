require "graphql"

module GraphQL
  module Language
    module Nodes
      class FragmentDefinition < AbstractNode
        def to_inline_fragment
          InlineFragment.new(type: type, directives: directives, selections: selections)
        end
      end

      class InlineFragment < AbstractNode
        def to_inline_fragment
          self
        end
      end
    end
  end
end
