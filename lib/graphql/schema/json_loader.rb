require "graphql"
require "json"

module GraphQL
  class Schema
    module JSONLoader
      def self.define_schema(json)
        schema = JSON.load(json).fetch("data").fetch("__schema")
        types = Schema::JSONLoader.define_types(schema)
        # TODO: handle schema["mutationType"]
        # TODO: handle schema["subscriptionType"]
        query = types.fetch(schema.fetch("queryType").fetch("name"))
        Schema.new(query: query, types: types.values)
      end

      def self.define_types(schema)
        schema.fetch("types").inject({}) do |types, type|
          type_kind, type_name = type.fetch("kind"), type.fetch("name")

          if !type_name.start_with?("__")
            case type_kind
            when "INTERFACE"
              types[type_name] = define_interface(types, type)
            when "OBJECT"
              types[type_name] = define_object(types, type)
            when "SCALAR"
              types[type_name] = define_scalar(types, type)
            else
              # TODO: handle other type kinds
              fail NotImplementedError, type_kind + " not implemented"
            end
          end

          types
        end
      end

      def self.resolve_type(types, type)
        case kind = type.fetch("kind")
        when "INTERFACE"
          types.fetch(type.fetch("name"))
        when "LIST"
          ListType.new(of_type: resolve_type(types, type.fetch("ofType")))
        when "NON_NULL"
          NonNullType.new(of_type: resolve_type(types, type.fetch("ofType")))
        when "OBJECT"
          types.fetch(type.fetch("name"))
        when "SCALAR"
          types.fetch(type.fetch("name"))
        else
          # TODO: handle other type kinds
          fail NotImplementedError, kind + " not implemented"
        end
      end

      def self.define_interface(types, type)
        InterfaceType.define do
          name type.fetch("name")
        end
      end

      def self.define_object(types, type)
        ObjectType.define do
          name type.fetch("name")
          description type["description"]

          Array(type["fields"]).each do |field_data|
            field field_data["name"] do
              type JSONLoader.resolve_type(types, field_data["type"])
              description field_data["description"]
              field_data["args"].each do |arg|
                argument arg["name"] do
                  type JSONLoader.resolve_type(types, arg["type"])
                  description arg["description"]
                end
              end
            end
          end
        end
      end

      def self.define_scalar(types, type)
        case name = type.fetch("name")
        when "Int"
          INT_TYPE
        when "String"
          STRING_TYPE
        when "Float"
          FLOAT_TYPE
        when "Boolean"
          BOOLEAN_TYPE
        when "ID"
          ID_TYPE
        else
          # TODO: handle other scalar names
          fail NotImplementedError, name + " scalar not implemented"
        end
      end
    end
  end
end
