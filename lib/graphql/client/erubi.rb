# frozen_string_literal: true
require "action_view"
require "graphql/client/erubi_enhancer"

module GraphQL
  class Client
    # Ignore deprecation errors loading AV Erubis
    ActiveSupport::Deprecation.silence do
      ActionView::Template::Handlers::ERB::Erubi
    end

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
    class Erubi < ActionView::Template::Handlers::ERB::Erubi
      include ErubiEnhancer
    end
  end
end
