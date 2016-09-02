require "graphql"
require "graphql/language/nodes/inlined_fragment_definition"
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
                InlinedFragmentDefinition.new(original_definition: fragment, type: fragment.type, directives: fragment.directives, selections: fragment.selections)
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
