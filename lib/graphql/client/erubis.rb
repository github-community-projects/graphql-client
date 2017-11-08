# frozen_string_literal: true
require "action_view"
require "graphql/client/erubis_enhancer"

module GraphQL
  class Client
    # Ignore deprecation errors loading AV Erubis
    ActiveSupport::Deprecation.silence do
      ActionView::Template::Handlers::Erubis
    end

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
    class Erubis < ActionView::Template::Handlers::Erubis
      include ErubisEnhancer
    end
  end
end
