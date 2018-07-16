# frozen_string_literal: true
require "action_view"

module GraphQL
  class Client
    begin
      require "action_view/template/handlers/erb/erubi"
    rescue LoadError
      require "graphql/client/erubis_enhancer"

      # Public: Extended Erubis implementation that supports GraphQL static
      # query sections.
      #
      #   <%graphql
      #     query GetVersion {
      #       version
      #     }
      #   %>
      #   <%= data.version %>
      #
      # Configure ActionView's default ERB implementation to use this class.
      #
      #   ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubis
      #
      class ERB < ActionView::Template::Handlers::Erubis
        include ErubisEnhancer
      end
    else
      require "graphql/client/erubi_enhancer"

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
      #   ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubi
      #
      class ERB < ActionView::Template::Handlers::ERB::Erubi
        include ErubiEnhancer
      end
    end
  end
end
