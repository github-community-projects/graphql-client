# frozen_string_literal: true

module GraphQL
  class Client
    module Schema
      module BaseType
        # Public: Get associated GraphQL::BaseType with for this class.
        attr_reader :type

        # Internal: Get owner schema Module container.
        attr_accessor :schema_module

        # Internal: Cast JSON value to wrapped value.
        #
        # value - JSON value
        # errors - Errors instance
        #
        # Returns BaseType instance.
        def cast(value, errors)
          raise NotImplementedError, "subclasses must implement #cast(value, errors)"
        end

        # Internal: Get non-nullable wrapper of this type class.
        #
        # Returns NonNullType instance.
        def to_non_null_type
          @null_type ||= NonNullType.new(self)
        end

        # Internal: Get list wrapper of this type class.
        #
        # Returns ListType instance.
        def to_list_type
          @list_type ||= ListType.new(self)
        end
      end
    end
  end
end
