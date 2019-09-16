# frozen_string_literal: true

require "graphql/client/error"
require "graphql/client/schema/base_type"

module GraphQL
  class Client
    module Schema
      class EnumType < Module
        include BaseType

        class EnumValue < String
          def initialize(obj, enum_value, enum)
            super(obj)
            @enum_value = enum_value
            @enum = enum
          end

          def respond_to_missing?(method_name, include_private = false)
            if method_name[-1] == "?" && @enum.include?(method_name[0..-2])
              true
            else
              super
            end
          end

          def method_missing(method_name, *args)
            if method_name[-1] == "?"
              queried_value = method_name[0..-2]
              if @enum.include?(queried_value)
                raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" unless args.empty?
                return @enum_value == queried_value
              end
            end

            super
          end
        end

        # Internal: Construct enum wrapper from another GraphQL::EnumType.
        #
        # type - GraphQL::EnumType instance
        def initialize(type)
          unless type.kind.enum?
            raise "expected type to be an Enum, but was #{type.class}"
          end

          @type = type
          @values = {}

          all_values = type.values.keys
          comparison_set = all_values.map { |s| -s.downcase }.to_set

          all_values.each do |value|
            str = EnumValue.new(-value, -value.downcase, comparison_set).freeze
            const_set(value, str) if value =~ /^[A-Z]/
            @values[str.to_s] = str
          end

          @values.freeze
        end

        def define_class(definition, ast_nodes)
          self
        end

        def [](value)
          @values[value]
        end

        # Internal: Cast JSON value to the enumeration's corresponding constant string instance
        #  with the convenience predicate methods.
        #
        # values - JSON value
        # errors - Errors instance
        #
        # Returns String or nil.
        def cast(value, _errors = nil)
          case value
          when String
            raise Error, "unexpected enum value #{value}" unless @values.key?(value)
            @values[value]
          when NilClass
            value
          else
            raise InvariantError, "expected value to be a String, but was #{value.class}"
          end
        end
      end
    end
  end
end
