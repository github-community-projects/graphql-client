# frozen_string_literal: true

require "graphql/client/definition"

module GraphQL
  class Client
    # Specific operation definition subtype for queries, mutations or
    # subscriptions.
    class OperationDefinition < Definition
      # Public: Alias for definition name.
      alias operation_name definition_name
    end
  end
end
