# frozen_string_literal: true

require "graphql"
require "graphql/client/schema/enum_type"
require "graphql/client/schema/include_directive"
require "graphql/client/schema/interface_type"
require "graphql/client/schema/list_type"
require "graphql/client/schema/non_null_type"
require "graphql/client/schema/object_type"
require "graphql/client/schema/scalar_type"
require "graphql/client/schema/skip_directive"
require "graphql/client/schema/union_type"

module GraphQL
  class Client
    module Schema
      module ClassMethods
        def define_class(definition, ast_nodes, type)
          type_class = case type.kind.name
          when "NON_NULL"
            define_class(definition, ast_nodes, type.of_type).to_non_null_type
          when "LIST"
            define_class(definition, ast_nodes, type.of_type).to_list_type
          else
            get_class(type.graphql_name).define_class(definition, ast_nodes)
          end

          ast_nodes.each do |ast_node|
            ast_node.directives.each do |directive|
              if directive = self.directives[directive.name.to_sym]
                type_class = directive.new(type_class)
              end
            end
          end

          type_class
        end

        def get_class(type_name)
          const_get(normalize_type_name(type_name))
        end

        def set_class(type_name, klass)
          class_name = normalize_type_name(type_name)

          if constants.include?(class_name.to_sym)
            raise ArgumentError,
              "Can't define #{class_name} to represent type #{type_name} " \
              "because it's already defined"
          end

          const_set(class_name, klass)
        end

        DIRECTIVES = { include: IncludeDirective,
                       skip: SkipDirective }.freeze

        def directives
          DIRECTIVES
        end

        private

        def normalize_type_name(type_name)
          /\A[A-Z]/.match?(type_name) ? type_name : type_name.camelize
        end
      end

      def self.generate(schema)
        mod = Module.new
        mod.extend ClassMethods

        cache = {}
        schema.types.each do |name, type|
          next if name.start_with?("__")
          if klass = class_for(schema, type, cache)
            klass.schema_module = mod
            mod.set_class(name, klass)
          end
        end

        mod
      end

      def self.class_for(schema, type, cache)
        return cache[type] if cache[type]

        case type.kind.name
        when "INPUT_OBJECT"
          nil
        when "SCALAR"
          cache[type] = ScalarType.new(type)
        when "ENUM"
          cache[type] = EnumType.new(type)
        when "LIST"
          cache[type] = class_for(schema, type.of_type, cache).to_list_type
        when "NON_NULL"
          cache[type] = class_for(schema, type.of_type, cache).to_non_null_type
        when "UNION"
          klass = cache[type] = UnionType.new(type)

          type.possible_types.each do |possible_type|
            possible_klass = class_for(schema, possible_type, cache)
            possible_klass.send :include, klass
          end

          klass
        when "INTERFACE"
          cache[type] = InterfaceType.new(type)
        when "OBJECT"
          klass = cache[type] = ObjectType.new(type)

          type.interfaces.each do |interface|
            klass.send :include, class_for(schema, interface, cache)
          end
          # Legacy objects have `.all_fields`
          all_fields = type.respond_to?(:all_fields) ? type.all_fields : type.fields.values
          all_fields.each do |field|
            klass.fields[field.name.to_sym] = class_for(schema, field.type, cache)
          end

          klass
        else
          raise TypeError, "unexpected #{type.class} (#{type.inspect})"
        end
      end
    end
  end
end
