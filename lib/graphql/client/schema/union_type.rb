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

        def define_class(definition, irep_node)
          new(irep_node.typed_children.keys.map { |ctype|
            schema_module.get_class(ctype.name).define_class(definition, irep_node)
          })
        end
      end
    end
  end
end
