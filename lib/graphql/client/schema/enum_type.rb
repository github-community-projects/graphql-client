# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class EnumType < Module
        include BaseType

        # Internal: Construct enum wrapper from another GraphQL::EnumType.
        #
        # type - GraphQL::EnumType instance
        def initialize(type)
          unless type.is_a?(GraphQL::EnumType)
            raise "expected type to be a GraphQL::EnumType, but was #{type.class}"
          end

          @type = type

          all_values = type.values.keys

          all_values.each do |value|
            str = value.dup
            all_values.each do |v|
              str.define_singleton_method("#{v.downcase}?") { false }
            end
            str.define_singleton_method("#{value.downcase}?") { true }
            str.freeze
            const_set(value, str)
          end
        end

        def define_class(definition, irep_node)
          self
        end

        # Internal: Cast JSON value to wrapped value.
        #
        # values - JSON value
        # errors - Errors instance
        #
        # Returns String or nil.
        def cast(value, _errors = nil)
          case value
          when String, NilClass
            value
          else
            raise InvariantError, "expected value to be a String, but was #{value.class}"
          end
        end
      end
    end
  end
end
