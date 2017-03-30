# frozen_string_literal: true
require "action_view"
require "graphql/client/erubis_enhancer"

module GraphQL
  class Client
    # Public: Extended Erubis implementation that supports GraphQL static
    # query sections.
    #
    #   <%graphql
    #     query GetVerison {
    #       version
    #     }
    #   %>
    #   <%= data.version %>
    #
    # Configure ActionView's default ERB implementation to use this class.
    #
    #   ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubis
    #
    class Erubis < ActionView::Template::Handlers::Erubis
      # Deprecated: Use ViewModule.extract_graphql_section.
      def self.extract_graphql_section(src)
        ViewModule.extract_graphql_section(src)
      end

      include ErubisEnhancer
    end
  end
end
