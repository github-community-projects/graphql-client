# typed: true
# frozen_string_literal: true

require "graphql/client"
require "graphql/client/http"
require "tapioca/dsl/helpers/graphql_type_helper"

module Tapioca
  module Dsl
    module Compilers
      class GraphqlClient < Compiler
        extend T::Sig

        # This is a hack to make Sorbet happy.
        # It's necessary because there's no static class that implements this interface.
        # See `GraphQL::Client::Schema::ObjectType.new`
        class TypeClass
          def self.fields; end
        end

        ConstantType = type_member { { fixed: T.class_of(TypeClass) } }

        sig { override.returns(T::Enumerable[Module]) }
        def self.gather_constants
          graphql_type_modules = all_modules
                                   .select { |mod| mod.singleton_class < GraphQL::Client::Schema::ClassMethods }
          graphql_types = graphql_type_modules.flat_map do |mod|
            mod_name = qualified_name_of(mod)
            next unless mod_name # Ignore anonymous modules

            mod.constants.map { |const| "#{mod_name}::#{const}".constantize }
          end
          graphql_types.select { |c| c.is_a?(Class) }
        end

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            constant.fields.each do |name, definition|
              define_field(klass, name, definition, constant)
            end
          end
        end

        private

        def define_field(klass, name, definition, constant)
          type = type_for(definition, constant)
          klass.create_method(name.to_s.underscore, return_type: type) if type
        end

        def type_for(definition, constant, nilable: true)
          type = case definition
                 when GraphQL::Client::Schema::NonNullType
                   nilable = false
                   type_for(definition.of_klass, constant, nilable: false)
                 when GraphQL::Client::Schema::ListType
                   sub_type = type_for(definition.of_klass, constant, nilable: nilable)
                   "T::Array[#{sub_type}]" if sub_type
                 when GraphQL::Client::Schema::ScalarType, GraphQL::Client::Schema::EnumType
                   argument = GraphQL::Schema::Argument.new(owner: nil)
                   argument.type = GraphQL::Schema::NonNull.new(definition.type)
                   Tapioca::Dsl::Helpers::GraphqlTypeHelper
                     .type_for_argument(argument, constant)
                 when GraphQL::Client::Schema::UnionType, GraphQL::Client::Schema::InterfaceType
                   nil
                 when Class
                   definition.name
                 else
                   raise "Unrecognised definition: #{definition}"
                 end
          return unless type

          type = "T.nilable(#{type})" if nilable && type != 'T.untyped'
          type
        end
      end
    end
  end
end
