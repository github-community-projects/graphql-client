require "graphql"

module GraphQL
  module Language
    module Nodes
      class Document < AbstractNode
        def definition_slice(name)
          definitions = []
          definitions << self.definitions.find { |d| d.name == name }

          visitor = Visitor.new(self)
          visitor[FragmentSpread] << proc do |node, parent|
            if fragment = self.definitions.find { |d| d.name == node.name }
              definitions << fragment
            end
          end
          visitor.visit

          self.class.new(definitions: definitions.uniq)
        end
      end
    end
  end
end
