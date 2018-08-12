# frozen_string_literal: true
require "graphql"
require "graphql/client"
require "graphql/client/controller_helpers"
require "rails/railtie"

module GraphQL
  class Client
    # Optional Rails configuration for GraphQL::Client.
    #
    # Simply require this file to activate in the application.
    #
    #   # config/application.rb
    #   require "graphql/client/railtie"
    #
    class Railtie < Rails::Railtie
      config.graphql = ActiveSupport::OrderedOptions.new

      initializer "graphql.configure_log_subscriber" do |_app|
        require "graphql/client/log_subscriber"
        GraphQL::Client::LogSubscriber.attach_to :graphql
      end

      initializer "graphql.configure_erb_implementation" do |_app|
        if Rails.version >= "5.1"
          require "graphql/client/erubi"
          ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubi
        else
          require "graphql/client/erubis"
          ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubis
        end
      end

      initializer "graphql.configure_controller_helpers" do |_app|
        ActiveSupport.on_load(:action_controller) do
          include GraphQL::Client::ControllerHelpers
        end
      end

      initializer "graphql.configure_views_namespace" do |app|
        require "graphql/client/view_module"

        path = app.paths["app/views"].first

        config.watchable_dirs[path] = [:erb]

        Object.const_set(:Views, Module.new do
          extend GraphQL::Client::ViewModule
          self.path = path
        end)
      end
    end
  end
end
