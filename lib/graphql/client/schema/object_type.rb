# frozen_string_literal: true
require "active_support/inflector"
require "graphql/client/error"
require "graphql/client/errors"
require "graphql/client/schema/base_type"
require "graphql/client/schema/possible_types"

module GraphQL
  class Client
    module Schema
      module ObjectType
        def self.new(type, fields = {})
          Class.new(ObjectClass) do
            extend BaseType
            extend ObjectType

            define_singleton_method(:type) { type }
            define_singleton_method(:fields) { fields }

            const_set(:READERS, {})
            const_set(:PREDICATES, {})
          end
        end

        class WithDefinition
          include BaseType
          include ObjectType

          EMPTY_SET = Set.new.freeze

          attr_reader :klass, :defined_fields, :definition

          def type
            @klass.type
          end

          def fields
            @klass.fields
          end

          def spreads
            if defined?(@spreads)
              @spreads
            else
              EMPTY_SET
            end
          end

          def initialize(klass, defined_fields, definition, spreads)
            @klass = klass
            @defined_fields = defined_fields.map do |k, v|
              [-k.to_s, v]
            end.to_h
            @definition = definition
            @spreads = spreads unless spreads.empty?

            @defined_fields.keys.each do |attr|
              name = ActiveSupport::Inflector.underscore(attr)
              @klass::READERS[:"#{name}"] ||= attr
              @klass::PREDICATES[:"#{name}?"] ||= attr
            end
          end

          def new(data = {}, errors = Errors.new)
            @klass.new(data, errors, self)
          end
        end

        def define_class(definition, ast_nodes)
          # First, gather all the ast nodes representing a certain selection, by name.
          # We gather AST nodes into arrays so that multiple selections can be grouped, for example:
          #
          #   {
          #     f1 { a b }
          #     f1 { b c }
          #   }
          #
          # should be treated like `f1 { a b c }`
          field_nodes = {}
          ast_nodes.each do |ast_node|
            ast_node.selections.each do |selected_ast_node|
              gather_selections(field_nodes, definition, selected_ast_node)
            end
          end

          # After gathering all the nodes by name, prepare to create methods and classes for them.
          field_classes = {}
          field_nodes.each do |result_name, field_ast_nodes|
            # `result_name` might be an alias, so make sure to get the proper name
            field_name = field_ast_nodes.first.name
            field_definition = definition.client.schema.get_field(type.graphql_name, field_name)
            field_return_type = field_definition.type
            field_classes[result_name.to_sym] = schema_module.define_class(definition, field_ast_nodes, field_return_type)
          end

          spreads = definition.indexes[:spreads][ast_nodes.first]

          WithDefinition.new(self, field_classes, definition, spreads)
        end

        def define_field(name, type)
          name = name.to_s
          method_name = ActiveSupport::Inflector.underscore(name)

          define_method(method_name) do
            @casted_data.fetch(name) do
              @casted_data[name] = type.cast(@data[name], @errors.filter_by_path(name))
            end
          end

          define_method("#{method_name}?") do
            @data[name] ? true : false
          end
        end

        def cast(value, errors)
          case value
          when Hash
            new(value, errors)
          when NilClass
            nil
          else
            raise InvariantError, "expected value to be a Hash, but was #{value.class}"
          end
        end

        private

        # Given an AST selection on this object, gather it into `fields` if it applies.
        # If it's a fragment, continue recursively checking the selections on the fragment.
        def gather_selections(fields, definition, selected_ast_node)
          case selected_ast_node
          when GraphQL::Language::Nodes::InlineFragment
            continue_selection = if selected_ast_node.type.nil?
              true
            else
              type_condition = definition.client.get_type(selected_ast_node.type.name)
              applicable_types = definition.client.possible_types(type_condition)
              # continue if this object type is one of the types matching the fragment condition
              applicable_types.include?(type)
            end

            if continue_selection
              selected_ast_node.selections.each do |next_selected_ast_node|
                gather_selections(fields, definition, next_selected_ast_node)
              end
            end
          when GraphQL::Language::Nodes::FragmentSpread
            fragment_definition = definition.document.definitions.find do |defn|
              defn.is_a?(GraphQL::Language::Nodes::FragmentDefinition) && defn.name == selected_ast_node.name
            end
            type_condition = definition.client.get_type(fragment_definition.type.name)
            applicable_types = definition.client.possible_types(type_condition)
            # continue if this object type is one of the types matching the fragment condition
            continue_selection = applicable_types.include?(type)

            if continue_selection
              fragment_definition.selections.each do |next_selected_ast_node|
                gather_selections(fields, definition, next_selected_ast_node)
              end
            end
          when GraphQL::Language::Nodes::Field
            operation_definition_for_field = definition.indexes[:definitions][selected_ast_node]
            # Ignore fields defined in other documents.
            if definition.source_document.definitions.include?(operation_definition_for_field)
              field_method_name = selected_ast_node.alias || selected_ast_node.name
              ast_nodes = fields[field_method_name] ||= []
              ast_nodes << selected_ast_node
            end
          else
            raise "Unexpected selection node: #{selected_ast_node}"
          end
        end
      end

      class ObjectClass
        def initialize(data = {}, errors = Errors.new, definer = nil)
          @data = data
          @casted_data = {}
          @errors = errors

          # If we are not provided a definition, we can use this empty default
          definer ||= ObjectType::WithDefinition.new(self.class, {}, nil, [])

          @definer = definer
          @enforce_collocated_callers = source_definition && source_definition.client.enforce_collocated_callers
        end

        # Public: Returns the raw response data
        #
        # Returns Hash
        def to_h
          @data
        end

        def _definer
          @definer
        end

        def _spreads
          @definer.spreads
        end

        def source_definition
          @definer.definition
        end

        def respond_to_missing?(name, priv)
          if (attr = self.class::READERS[name]) || (attr = self.class::PREDICATES[name])
            @definer.defined_fields.key?(attr) || super
          else
            super
          end
        end

        # Public: Return errors associated with data.
        #
        # It's possible to define "errors" as a field. Ideally this shouldn't
        # happen, but if it does we should prefer the field rather than the
        # builtin error type.
        #
        # Returns Errors collection.
        def errors
          if type = @definer.defined_fields["errors"]
            read_attribute("errors", type)
          else
            @errors
          end
        end

        def method_missing(name, *args)
          if (attr = self.class::READERS[name]) && (type = @definer.defined_fields[attr])
            if @enforce_collocated_callers
              verify_collocated_path do
                read_attribute(attr, type)
              end
            else
              read_attribute(attr, type)
            end
          elsif (attr = self.class::PREDICATES[name]) && @definer.defined_fields[attr]
            has_attribute?(attr)
          else
            begin
              super
            rescue NoMethodError => e
              type = self.class.type

              if ActiveSupport::Inflector.underscore(e.name.to_s) != e.name.to_s
                raise e
              end

              all_fields = type.respond_to?(:all_fields) ? type.all_fields : type.fields.values
              field = all_fields.find do |f|
                f.name == e.name.to_s || ActiveSupport::Inflector.underscore(f.name) == e.name.to_s
              end

              unless field
                raise UnimplementedFieldError, "undefined field `#{e.name}' on #{type.graphql_name} type. https://git.io/v1y3m"
              end

              if @data.key?(field.name)
                raise ImplicitlyFetchedFieldError, "implicitly fetched field `#{field.name}' on #{type} type. https://git.io/v1yGL"
              else
                raise UnfetchedFieldError, "unfetched field `#{field.name}' on #{type} type. https://git.io/v1y3U"
              end
            end
          end
        end

        def inspect
          parent = self.class
          until parent.superclass == ObjectClass
            parent = parent.superclass
          end

          ivars = @data.map { |key, value|
            if value.is_a?(Hash) || value.is_a?(Array)
              "#{key}=..."
            else
              "#{key}=#{value.inspect}"
            end
          }

          buf = "#<#{parent.name}".dup
          buf << " " << ivars.join(" ") if ivars.any?
          buf << ">"
          buf
        end

        private

        def verify_collocated_path
          location = caller_locations(2, 1)[0]

          CollocatedEnforcement.verify_collocated_path(location, source_definition.source_location[0]) do
            yield
          end
        end

        def read_attribute(attr, type)
          @casted_data.fetch(attr) do
            @casted_data[attr] = type.cast(@data[attr], @errors.filter_by_path(attr))
          end
        end

        def has_attribute?(attr)
          !!@data[attr]
        end
      end
    end
  end
end
