require "graphql"
require "active_support/inflector"

module GraphQL
  module Client
    class QueryResult
      def self.fields
        @fields
      end

      def self.define(fields: {})
        Class.new(self) do
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

      def self.inspect
        "#<GraphQL::Client::QueryResult fields=#{@fields.keys.inspect}>"
      end

      def self.cast(obj)
        case obj
        when Hash
          new(obj)
        when GraphQL::QueryResult
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

      attr_reader :data
      alias_method :to_h, :data

      def inspect
        ivars = (self.class.fields.keys - [:__typename]).map { |sym| "#{sym}=#{instance_variable_get("@#{sym}").inspect}" }
        buf = "#<GraphQL::Client::QueryResult"
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
