require "graphql"
require "active_support/inflector"

module GraphQL
  module Client
    class QueryResult
      def self.source_node
        @source_node
      end

      def self.fields
        @fields
      end

      def self.define(source_node: nil, fields: {})
        Class.new(self) do
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

      def self.name
        super || GraphQL::Client::QueryResult.name
      end

      def self.inspect
        "#<#{self.name} fields=#{@fields.keys.inspect}>"
      end

      def self.cast(obj)
        case obj
        when Hash
          new(obj)
        when QueryResult
          unless obj.class.source_node.selections.include?(self.source_node)
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
        define(source_node: self.source_node, fields: new_fields)
      end

      attr_reader :data
      alias_method :to_h, :data

      def inspect
        ivars = (self.class.fields.keys - [:__typename]).map { |sym| "#{sym}=#{instance_variable_get("@#{sym}").inspect}" }
        buf = "#<#{self.class.name}"
        buf << " " << @__typename if @__typename
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
