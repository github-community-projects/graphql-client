require "rubocop"

module RuboCop
  module Cop
    module GraphQL
      # Public: Cop for enforcing non-interpolated GRAPHQL heredocs.
      class Heredoc < Cop
        def on_str(node)
          return unless node.location.is_a?(Parser::Source::Map::Heredoc)
          return unless node.location.expression.source == "<<-GRAPHQL"

          add_offense(node, :expression, "GraphQL heredocs should be quoted. <<-'GRAPHQL'")
        end
      end
    end
  end
end
