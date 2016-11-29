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
      # Internal: Get QueryResult class for result of query.
      #
      # Returns subclass of QueryResult or nil.
      def self.wrap(node, name: nil)
        fields = {}

        node.selections.each do |selection|
          case selection
          when Language::Nodes::FragmentSpread
            nil
          when Language::Nodes::Field
            field_name = selection.alias || selection.name
            field_klass = selection.selections.any? ? wrap(selection, name: "#{name}[:#{field_name}]") : nil
            fields[field_name] ? fields[field_name] |= field_klass : fields[field_name] = field_klass
          when Language::Nodes::InlineFragment
            wrap(selection, name: name).fields.each do |fragment_name, klass|
              fields[fragment_name.to_s] ? fields[fragment_name.to_s] |= klass : fields[fragment_name.to_s] = klass
            end
          end
        end

        define(name: name, source_node: node, fields: fields)
      end

      # Internal
      def self.define(name:, source_node:, fields: {})
        Class.new(self) do
          @name = name
          @source_node = source_node
          @fields = {}

          fields.each do |field, type|
            @fields[field.to_sym] = type

            send :attr_reader, field

            # Convert GraphQL camelcase to snake case: commitComments -> commit_comments
            field_alias = ActiveSupport::Inflector.underscore(field)
            send :alias_method, field_alias, field if field != field_alias

            class_eval <<-RUBY, __FILE__, __LINE__
              def #{field_alias}?
                #{field_alias} ? true : false
              end
            RUBY

            next unless field == "edges"
            class_eval <<-RUBY, __FILE__, __LINE__
              def each_node
                return enum_for(:each_node) unless block_given?
                edges.each { |edge| yield edge.node }
                self
              end
            RUBY
          end

          assigns = fields.map do |field, type|
            if type
              <<-RUBY
                @#{field} = self.class.fields[:#{field}].cast(@data["#{field}"], @errors.filter_by_path("#{field}"))
              RUBY
            else
              <<-RUBY
                @#{field} = @data["#{field}"]
              RUBY
            end
          end

          class_eval <<-RUBY, __FILE__, __LINE__
            def initialize(data, errors = Errors.new)
              @data = data
              @errors = errors

              #{assigns.join("\n")}
              freeze
            end
          RUBY
        end
      end

      class << self
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
        define(name: self.name, source_node: source_node, fields: new_fields)
      end

      # Public: Return errors associated with data.
      #
      # Returns Errors collection.
      attr_reader :errors

      attr_reader :data
      alias to_h data

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
        raise NoMethodError, "undefined method `#{e.name}' for #{inspect}"
      end

      def respond_to_missing?(*args)
        super
      end
    end
  end
end
