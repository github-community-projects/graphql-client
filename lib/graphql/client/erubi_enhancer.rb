# frozen_string_literal: true

module GraphQL
  class Client
    # Public: Erubi enhancer that adds support for GraphQL static query sections.
    #
    #   <%graphql
    #     query GetVersion {
    #       version
    #     }
    #   %>
    #   <%= data.version %>
    #
    module ErubiEnhancer
      # Internal: Extend Erubi handler to simply ignore <%graphql sections.
      def initialize(input, *args)
        input = input.gsub(/<%graphql/, "<%#")
        super(input, *args)
      end
    end
  end
end
