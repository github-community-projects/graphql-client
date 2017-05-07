# frozen_string_literal: true

require "graphql/client/schema/possible_types"

module GraphQL
  class Client
    module Schema
      class UnionType < Module
        include BaseType

        def initialize(type)
          unless type.is_a?(GraphQL::UnionType)
            raise "expected type to be a GraphQL::UnionType, but was #{type.class}"
          end

          @type = type
        end

        def new(types)
          PossibleTypes.new(type, types)
        end
      end
    end
  end
end
