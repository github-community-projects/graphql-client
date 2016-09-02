require "graphql"
require "graphql/language/nodes/fragment_ext"
require "graphql/language/nodes/selection_ext"

module GraphQL
  module Language
    module Nodes
      module Selections
        def replace_fragment_spread(fragments)
          other = self.dup
          other.selections = self.selections.map do |selection|
            case selection
            when FragmentSpread
              if fragment = fragments[selection.name.to_sym]
                fragment.to_inline_fragment
              else
                selection
              end
            when Selections
              selection.replace_fragment_spread(fragments)
            else
              selection
            end
          end
          other
        end
      end

      class Document < AbstractNode
        def replace_fragment_spread(fragments)
          other = self.dup
          other.definitions = self.definitions.map do |definition|
            case definition
            when Selections
              definition.replace_fragment_spread(fragments)
            else
              definition
            end
          end
          other
        end
      end
    end
  end
end
