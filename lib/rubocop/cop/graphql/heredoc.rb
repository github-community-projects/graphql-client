# frozen_string_literal: true
require "rubocop"

module RuboCop
  module Cop
    module GraphQL
      # Public: Cop for enforcing non-interpolated GRAPHQL heredocs.
      class Heredoc < Cop
        def on_dstr(node)
          check_str(node)
        end

        def on_str(node)
          check_str(node)
        end

        def check_str(node)
          return unless node.location.is_a?(Parser::Source::Map::Heredoc)
          return unless node.location.expression.source == "<<-GRAPHQL"

          add_offense(node, :expression, "GraphQL heredocs should be quoted. <<-'GRAPHQL'")
        end

        def autocorrect(node)
          ->(corrector) do
            corrector.replace(node.location.expression, "<<-'GRAPHQL'")
          end
        end
      end
    end
  end
end
