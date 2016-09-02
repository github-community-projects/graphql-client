require "graphql"

module GraphQL
  module Language
    module Nodes
      class InlinedFragmentDefinition < InlineFragment
        attr_reader :original_definition

        def initialize(original_definition:, **kargs)
          @original_definition = original_definition
          unless @original_definition.frozen?
            raise RuntimeError, "original FragmentDefinition must be immutable"
          end

          super(**kargs)
        end
      end
    end
  end
end
