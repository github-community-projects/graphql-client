# frozen_string_literal: true

require "graphql/client/definition"

module GraphQL
  class Client
    # Specific fragment definition subtype.
    class FragmentDefinition < Definition
      def new(obj, *args)
        if obj.is_a?(Hash)
          raise TypeError, "constructing fragment wrapper from Hash is deprecated"
        end

        super
      end
    end
  end
end
