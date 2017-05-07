# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class NonNullType
        include BaseType

        # Internal: Construct non-nullable wrapper from other BaseType.
        #
        # of_klass - BaseType instance
        def initialize(of_klass)
          unless of_klass.is_a?(BaseType)
            raise TypeError, "expected #{of_klass.inspect} to be a #{BaseType}"
          end

          @of_klass = of_klass
        end

        # Internal: Get wrapped klass.
        #
        # Returns BaseType instance.
        attr_reader :of_klass

        # Internal: Cast JSON value to wrapped value.
        #
        # value - JSON value
        # errors - Errors instance
        #
        # Returns BaseType instance.
        def cast(value, errors)
          case value
          when NilClass
            raise InvariantError, "expected value to be non-nullable, but was nil"
          else
            of_klass.cast(value, errors)
          end
        end

        # Internal: Get non-nullable wrapper of this type class.
        #
        # Returns NonNullType instance.
        def to_non_null_type
          self
        end
      end
    end
  end
end
