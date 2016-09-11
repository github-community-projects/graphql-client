module GraphQL
  class Client
    class Query
      # Internal: Construct Query.
      #
      # Avoid creating queries with this constructor, perfer using Client#query.
      #
      # document - A parsed GraphQL::Language::Nodes::Document of the query
      # operation_name - String operation to execute
      # variables - Hash of variables to execute with the operation
      # context - Hash of metadata to pass to network adapter
      def initialize(document, operation_name: nil, variables: {}, context: {})
        @document = document
        @operation_name = operation_name
        @variables = variables
        @context = context
      end

      # Public: A parsed GraphQL::Language::Nodes::Document of the query.
      attr_reader :document

      # Public: String name of operation to execute.
      attr_reader :operation_name

      # Public: Hash of variables to execute with the operation.
      attr_reader :variables

      # Public: Hash of contextual metadata.
      attr_reader :context

      # Public: Serialized query string
      #
      # Returns String.
      def to_s
        document.to_query_string
      end

      # Public: Get operation definition node.
      #
      # Returns GraphQL::Language::Nodes::OperationDefinition.
      def operation
        document.definitions.find { |node| node.name == operation_name }
      end

      # Public: Query operation type
      #
      # Returns "query", "mutation" or "subscription".
      def operation_type
        operation.operation_type
      end

      # Internal: Payload object to pass to ActiveSupport::Notifications.
      #
      # Returns Hash.
      def payload
        {
          document: document,
          operation_name: operation_name,
          operation_type: operation_type,
          variables: variables
        }
      end
    end
  end
end
