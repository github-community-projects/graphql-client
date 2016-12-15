# frozen_string_literal: true
require "active_support/inflector"
require "graphql"
require "graphql/client/errors"
require "graphql/client/list"
require "set"

module GraphQL
  class Client
    # A QueryResult struct wraps data returned from a GraphQL response.
    #
    # Wrapping the JSON-like Hash allows access with nice Ruby accessor methods
    # rather than using `obj["key"]` access.
    #
    # Wrappers also limit field visibility to fragment definitions.
    class QueryResult
      class NoFieldError < Error; end
      class ImplicitlyFetchedFieldError < NoFieldError; end
      class UnfetchedFieldError < NoFieldError; end
      class UnimplementedFieldError < NoFieldError; end

      # Internal: Get QueryResult class for result of query.
      #
      # Returns subclass of QueryResult or nil.
      def self.wrap(source_definition, node, name: nil)
        fields = {}

        node.selections.each do |selection|
          case selection
          when Language::Nodes::FragmentSpread
            nil
          when Language::Nodes::Field
            field_name = selection.alias || selection.name
            field_klass = nil
            if selection.selections.any?
              field_klass = wrap(source_definition, selection, name: "#{name}[:#{field_name}]")
            end
            fields[field_name] ? fields[field_name] |= field_klass : fields[field_name] = field_klass
          when Language::Nodes::InlineFragment
            wrap(source_definition, selection, name: name).fields.each do |fragment_name, klass|
              fields[fragment_name.to_s] ? fields[fragment_name.to_s] |= klass : fields[fragment_name.to_s] = klass
            end
          end
        end

        define(name: name, source_definition: source_definition, source_node: node, fields: fields)
      end

      # :nodoc:
      class Scalar
        def initialize(type)
          @type = type
        end

        def cast(value, _errors = nil)
          @type.coerce_input(value)
        end

        def |(_other)
          # XXX: How would scalars merge?
          self
        end
      end

      # Internal
      def self.define(name:, source_definition:, source_node:, fields: {})
        type = source_definition.document_types[source_node]
        type = type.unwrap if type

        Class.new(self) do
          @name = name
          @type = type
          @source_node = source_node
          @source_definition = source_definition
          @fields = {}

          field_readers = Set.new

          fields.each do |field, klass|
            if @type.is_a?(GraphQL::ObjectType)
              field_node = @type.fields[field.to_s]
              if field_node && field_node.type.unwrap.is_a?(GraphQL::ScalarType)
                klass = Scalar.new(field_node.type.unwrap)
              end
            end

            @fields[field.to_sym] = klass

            send :attr_reader, field
            field_readers << field.to_sym

            # Convert GraphQL camelcase to snake case: commitComments -> commit_comments
            field_alias = ActiveSupport::Inflector.underscore(field)
            send :alias_method, field_alias, field if field != field_alias
            field_readers << field_alias.to_sym

            class_eval <<-RUBY, __FILE__, __LINE__
              def #{field_alias}?
                #{field_alias} ? true : false
              end
            RUBY
            field_readers << "#{field_alias}?".to_sym

            next unless field == "edges"
            class_eval <<-RUBY, __FILE__, __LINE__
              def each_node
                return enum_for(:each_node) unless block_given?
                edges.each { |edge| yield edge.node }
                self
              end
            RUBY
            field_readers << :each_node
          end

          assigns = @fields.map do |field, klass|
            if klass
              <<-RUBY
                @#{field} = self.class.fields[:#{field}].cast(@data["#{field}"], @errors.filter_by_path("#{field}"))
              RUBY
            else
              <<-RUBY
                @#{field} = @data["#{field}"]
              RUBY
            end
          end

          if @type && @type.is_a?(GraphQL::ObjectType)
            assigns.unshift "@__typename = self.class.type.name"
          end

          class_eval <<-RUBY, __FILE__, __LINE__
            def initialize(data, errors = Errors.new)
              @data = data
              @errors = errors

              #{assigns.join("\n")}
              freeze
            end
          RUBY

          if @source_definition.enforce_collocated_callers
            Client.enforce_collocated_callers(self, field_readers, source_definition.source_location[0])
          end
        end
      end

      class << self
        attr_reader :type

        attr_reader :source_definition

        attr_reader :source_node

        attr_reader :fields

        def [](name)
          fields[name]
        end
      end

      def self.name
        @name || super || GraphQL::Client::QueryResult.name
      end

      def self.inspect
        "#<#{name} fields=#{@fields.keys.inspect}>"
      end

      def self.cast(obj, errors = Errors.new)
        case obj
        when Hash
          new(obj, errors)
        when self
          obj
        when QueryResult
          spreads = Set.new(self.spreads(obj.class.source_node).map(&:name))

          unless spreads.include?(source_node.name)
            raise TypeError, "couldn't cast #{obj.inspect} to #{inspect}"
          end
          cast(obj.to_h, obj.errors)
        when Array
          List.new(obj.each_with_index.map { |e, idx| cast(e, errors.filter_by_path(idx)) }, errors)
        when NilClass
          nil
        else
          raise TypeError, obj.class.to_s
        end
      end

      # Internal
      def self.spreads(node)
        node.selections.flat_map do |selection|
          case selection
          when Language::Nodes::FragmentSpread
            selection
          when Language::Nodes::InlineFragment
            spreads(selection)
          else
            []
          end
        end
      end

      def self.new(obj, *args)
        case obj
        when Hash
          super
        else
          cast(obj, *args)
        end
      end

      def self.|(other)
        new_fields = fields.dup
        other.fields.each do |name, value|
          if new_fields[name]
            new_fields[name] |= value
          else
            new_fields[name] = value
          end
        end
        # TODO: Picking first source node seems error prone
        define(name: self.name, source_definition: source_definition, source_node: source_node, fields: new_fields)
      end

      # Public: Return errors associated with data.
      #
      # Returns Errors collection.
      attr_reader :errors

      attr_reader :data
      alias to_h data

      attr_reader :__typename
      alias typename __typename

      def inspect
        ivars = self.class.fields.keys.map do |sym|
          value = instance_variable_get("@#{sym}")
          if value.is_a?(QueryResult)
            "#{sym}=#<#{value.class.name}>"
          else
            "#{sym}=#{value.inspect}"
          end
        end
        buf = "#<#{self.class.name}".dup
        buf << " " << ivars.join(" ") if ivars.any?
        buf << ">"
        buf
      end

      def method_missing(*args)
        super
      rescue NoMethodError => e
        type = self.class.type
        raise e unless type

        unless type.fields[e.name.to_s]
          raise UnimplementedFieldError, "undefined field `#{e.name}' on #{type} type. https://git.io/v1y3m"
        end

        if data[e.name.to_s]
          error_class = ImplicitlyFetchedFieldError
          message = "implicitly fetched field `#{e.name}' on #{type} type. https://git.io/v1yGL"
        else
          error_class = UnfetchedFieldError
          message = "unfetched field `#{e.name}' on #{type} type. https://git.io/v1y3U"
        end

        node = self.class.source_node
        message += "\n\n" + node.to_query_string.sub(/\}$/, "+ #{e.name}\n}") if node
        raise error_class, message
      end

      def respond_to_missing?(*args)
        super
      end
    end
  end
end
