require "active_support/inflector"
require "active_support/notifications"
require "graphql"
require "graphql/client/query_result"
require "graphql/language/nodes/deep_freeze_ext"
require "graphql/language/operation_slice"

module GraphQL
  class Client
    class Error < StandardError; end
    class ValidationError < Error; end

    class ResponseError < Error
      def initialize(definition, error)
        @request_definition = definition
        @locations = error["locations"]
        super error["message"]
      end
    end

    class ResponseErrors < Error
      include Enumerable

      attr_reader :errors

      def initialize(definition, errors)
        @request_definition = definition
        @errors = errors.map { |error| ResponseError.new(definition, error) }
        super @errors.map(&:message).join(", ")
      end

      def each(&block)
        errors.each(&block)
      end
    end

    attr_reader :schema, :fetch

    attr_accessor :document_tracking_enabled

    def self.load_schema(schema)
      case schema
      when GraphQL::Schema
        schema
      when Hash
        GraphQL::Schema::Loader.load(schema)
      when String
        if schema.end_with?(".json")
          load_schema(File.read(schema))
        else
          load_schema(JSON.parse(schema))
        end
      else
        nil
      end
    end

    def initialize(schema: nil, fetch: nil)
      @schema = self.class.load_schema(schema)
      @fetch = fetch
      @document = GraphQL::Language::Nodes::Document.new(definitions: [])
      @document_tracking_enabled = false
    end

    class Definition < Module
      def self.for(node:, **kargs)
        case node
        when Language::Nodes::OperationDefinition
          OperationDefinition.new(node: node, **kargs)
        when Language::Nodes::FragmentDefinition
          FragmentDefinition.new(node: node, **kargs)
        else
          raise TypeError, "expected node to be a definition type, but was #{node.class}"
        end
      end

      def initialize(node:, document:)
        @definition_node = node
        @document = document
      end

      # Internal: Get underlying operation or fragment defintion AST node for
      # definition.
      #
      # Returns OperationDefinition or FragmentDefinition object.
      attr_reader :definition_node

      # Public: Global name of definition in client document.
      #
      # Returns a GraphQL safe name of the Ruby constant String.
      #
      #   "Users::UserQuery" #=> "Users__UserQuery"
      #
      # Returns String.
      def definition_name
        return @definition_name if defined?(@definition_name)

        if name
          @definition_name = name.gsub("::", "__").freeze
        else
          "#{self.class.name}_#{object_id}".gsub("::", "__").freeze
        end
      end

      # Public: Get document with only the definitions needed to perform this
      # operation.
      #
      # Returns GraphQL::Language::Nodes::Document with one OperationDefinition
      # and any FragmentDefinition dependencies.
      attr_reader :document

      def new(*args)
        query_result_class.new(*args)
      end

      private
        def query_result_class
          @query_result_class ||= GraphQL::Client::QueryResult.wrap(definition_node, name: name)
        end
    end

    class OperationDefinition < Definition
      # Public: Alias for definition name.
      alias_method :operation_name, :definition_name
    end

    class FragmentDefinition < Definition
    end

    def parse(str)
      definition_dependencies = Set.new

      str = str.gsub(/\.\.\.([a-zA-Z0-9_]+(::[a-zA-Z0-9_]+)+)/) { |m|
        const_name = $1
        case fragment = ActiveSupport::Inflector.safe_constantize(const_name)
        when FragmentDefinition
          definition_dependencies.merge(fragment.document.definitions)
          "...#{fragment.definition_name}"
        when nil
          raise NameError, "uninitialized constant #{const_name}\n#{str}"
        else
          raise TypeError, "expected #{const_name} to be a #{FragmentDefinition}, but was a #{fragment.class}"
        end
      }

      doc = GraphQL.parse(str)

      doc.definitions.each do |node|
        node.name ||= "__anonymous__"
      end

      definition_dependencies.merge(doc.definitions)
      document_dependencies = Language::Nodes::Document.new(definitions: definition_dependencies.to_a)

      if @schema
        rules = GraphQL::StaticValidation::ALL_RULES - [GraphQL::StaticValidation::FragmentsAreUsed]
        validator = GraphQL::StaticValidation::Validator.new(schema: @schema, rules: rules)
        query = GraphQL::Query.new(@schema, document: document_dependencies)

        errors = validator.validate(query)
        errors.fetch(:errors).each do |error|
          raise ValidationError, error["message"] + "\n\n" + str
        end
      end

      definitions = {}
      doc.definitions.each do |node|
        node.name = nil if node.name == "__anonymous__"
        sliced_document = Language::OperationSlice.slice(document_dependencies, node.name)
        definition = Definition.for(node: node, document: sliced_document)
        definitions[node.name] = definition
      end

      rename_node = -> (node, parent) {
        if definition = definitions[node.name]
          node.extend(LazyName)
          node.name = -> { definition.definition_name }
        end
      }
      visitor = Language::Visitor.new(doc)
      visitor[Language::Nodes::FragmentDefinition].leave << rename_node
      visitor[Language::Nodes::OperationDefinition].leave << rename_node
      visitor[Language::Nodes::FragmentSpread].leave << rename_node
      visitor.visit

      doc.deep_freeze

      if document_tracking_enabled
        self.document.definitions.concat(doc.definitions)
      end

      if definitions[nil]
        definitions[nil]
      else
        Module.new do
          definitions.each do |name, definition|
            const_set(name, definition)
          end
        end
      end
    end

    def document
      @document
    end

    class Response
      attr_reader :extensions

      def initialize(extensions: nil)
        @extensions = extensions || {}
      end
    end

    class SuccessfulResponse < Response
      attr_reader :data

      def initialize(data:, **kargs)
        @data = data
        super(**kargs)
      end
    end

    class PartialResponse < SuccessfulResponse
      attr_reader :errors

      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    class FailedResponse < Response
      attr_reader :errors

      def initialize(errors:, **kargs)
        @errors = errors
        super(**kargs)
      end
    end

    class Query
      attr_reader :document, :operation_name, :variables, :context

      def initialize(document, operation_name: nil, variables: {}, context: {})
        @document = document
        @operation_name = operation_name
        @variables = variables
        @context = context
      end

      def to_s
        document.to_query_string
      end

      def operation
        document.definitions.find { |node| node.name == operation_name }
      end

      def operation_type
        operation.operation_type
      end

      def payload
        {
          document: document,
          operation_name: operation_name,
          operation_type: operation_type,
          variables: variables
        }
      end
    end

    def query(definition, variables: {}, context: {})
      unless fetch
        raise Error, "client network fetching not configured"
      end

      query = Query.new(definition.document,
        operation_name: definition.operation_name,
        variables: variables,
        context: context
      )

      result = ActiveSupport::Notifications.instrument("query.graphql", query.payload) do
        fetch.call(query)
      end

      data, errors, extensions = result.values_at("data", "errors", "extensions")

      if data && errors
        PartialResponse.new(
          data: definition.new(data),
          errors: ResponseErrors.new(definition, errors),
          extensions: extensions
        )
      elsif data && !errors
        SuccessfulResponse.new(
          data: definition.new(data),
          extensions: extensions
        )
      elsif !data && errors
        FailedResponse.new(
          errors: ResponseErrors.new(definition, errors),
          extensions: extensions
        )
      else
        raise Error, "invalid GraphQL response, expected data or errors"
      end
    end

    IntrospectionDocument = GraphQL.parse(GraphQL::Introspection::INTROSPECTION_QUERY).deep_freeze
    IntrospectionQuery = Query.new(IntrospectionDocument)

    def fetch_schema
      fetch.call(IntrospectionQuery)
    end

    private
      module LazyName
        def name
          @name.call
        end
      end
  end
end
