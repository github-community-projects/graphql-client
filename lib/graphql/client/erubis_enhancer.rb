# frozen_string_literal: true

module GraphQL
  class Client
    # Public: Erubis enhancer that adds support for GraphQL static query sections.
    #
    #   <%graphql
    #     query GetVersion {
    #       version
    #     }
    #   %>
    #   <%= data.version %>
    #
    module ErubisEnhancer
      # Internal: Extend Erubis handler to simply ignore <%graphql sections.
      def convert_input(src, input)
        input = input.gsub(/<%graphql/, "<%#")
        super(src, input)
      end
    end
  end
end
