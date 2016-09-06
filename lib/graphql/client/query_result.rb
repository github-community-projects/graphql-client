require "active_support/inflector"
require "graphql"
require "set"

module GraphQL
  class Client
    class QueryResult
      # Internal: Get QueryResult class for result of query.
      #
      # Returns subclass of QueryResult or nil.
      def self.wrap(node, name: nil)
        fields = {}

        node.selections.each do |selection|
          case selection
          when Language::Nodes::FragmentSpread
          when Language::Nodes::Field
            field_name = selection.alias || selection.name
            field_klass = selection.selections.any? ? wrap(selection, name: "#{name}.#{field_name}") : nil
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
            if field != field_alias
              send :alias_method, field_alias, field
            end

            class_eval <<-RUBY, __FILE__, __LINE__
              def #{field_alias}?
                #{field_alias} ? true : false
              end
            RUBY

            if field == "edges"
              class_eval <<-RUBY, __FILE__, __LINE__
                def each_node
                  return enum_for(:each_node) unless block_given?
                  edges.each { |edge| yield edge.node }
                  self
                end
              RUBY
            end
          end

          assigns = fields.map do |field, type|
            if type
              <<-RUBY
                @#{field} = self.class.fields[:#{field}].cast(@data["#{field}"])
              RUBY
            else
              <<-RUBY
                @#{field} = @data["#{field}"]
              RUBY
            end
          end

          class_eval <<-RUBY, __FILE__, __LINE__
            def initialize(data)
              @data = data
              #{assigns.join("\n")}
              freeze
            end
          RUBY
        end
      end

      def self.source_node
        @source_node
      end

      def self.fields
        @fields
      end

      def self.name
        @name || super || GraphQL::Client::QueryResult.name
      end

      def self.inspect
        "#<#{self.name} fields=#{@fields.keys.inspect}>"
      end

      def self.cast(obj)
        case obj
        when Hash
          new(obj)
        when QueryResult
          spreads = Set.new(obj.class.source_node.selections.select { |s| s.is_a?(GraphQL::Language::Nodes::FragmentSpread) }.map(&:name))

          if !spreads.include?(self.source_node.name)
            message = "couldn't cast #{obj.inspect} to #{self.inspect}\n\n"
            suggestion = "\n  ...#{name || "YourFragment"} # SUGGESTION"
            message << GraphQL::Language::Generation.generate(obj.class.source_node).sub(/\n}$/, "#{suggestion}\n}")
            raise TypeError, message
          end
          cast(obj.to_h)
        when Array
          obj.map { |e| cast(e) }
        when NilClass
          nil
        else
          raise TypeError, "#{obj.class}"
        end
      end

      def self.new(obj)
        case obj
        when Hash
          super
        else
          cast(obj)
        end
      end

      def self.|(other)
        new_fields = self.fields.dup
        other.fields.each do |name, value|
          if new_fields[name]
            new_fields[name] |= value
          else
            new_fields[name] = value
          end
        end
        # TODO: Picking first source node seems error prone
        define(name: self.name, source_node: self.source_node, fields: new_fields)
      end

      attr_reader :data
      alias_method :to_h, :data

      def inspect
        ivars = (self.class.fields.keys).map { |sym| "#{sym}=#{instance_variable_get("@#{sym}").inspect}" }
        buf = "#<#{self.class.name}"
        buf << " " << ivars.join(" ") if ivars.any?
        buf << ">"
        buf
      end

      def method_missing(*args)
        super
      rescue NoMethodError => e
        raise NoMethodError, "undefined method `#{e.name}' for #{inspect}"
      end
    end
  end
end
