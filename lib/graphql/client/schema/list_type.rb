# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/list"
require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class ListType
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
        def cast(values, errors)
          case values
          when Array
            List.new(values.each_with_index.map { |e, idx|
              of_klass.cast(e, errors.filter_by_path(idx))
            }, errors)
          when NilClass
            nil
          else
            raise InvariantError, "expected value to be a list, but was #{values.class}"
          end
        end

        # Internal: Get list wrapper of this type class.
        #
        # Returns ListType instance.
        def to_list_type
          self
        end
      end
    end
  end
end
