require "graphql"
require "graphql/language/nodes/selection_ext"

module GraphQL
  module Language
    module Nodes
      module Selections
        def inject_selection(*selections)
          other = self.dup
          other.selections = selections + self.selections.map do |selection|
            case selection
            when GraphQL::Language::Nodes::Selections
              selection.inject_selection(*selections)
            else
              selection
            end
          end
          other
        end
      end

      class Document < AbstractNode
        def inject_selection(*args)
          other = self.dup
          other.definitions = self.definitions.map do |definition|
            case definition
            when GraphQL::Language::Nodes::Selections
              definition.inject_selection(*args)
            else
              definition
            end
          end
          other
        end
      end

      class Field < AbstractNode
        def inject_selection(*selections)
          self.selections.any? ? super : self
        end
      end
    end
  end
end
