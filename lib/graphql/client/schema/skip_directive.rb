# frozen_string_literal: true

require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class SkipDirective
        include BaseType

        # Internal: Construct list wrapper from other BaseType.
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
        # values - JSON value
        # errors - Errors instance
        #
        # Returns List instance or nil.
        def cast(value, errors)
          case value
          when NilClass
            nil
          else
            of_klass.cast(value, errors)
          end
        end
      end
    end
  end
end
