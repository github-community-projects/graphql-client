require "graphql"
require "graphql/client"
require "graphql/client/log_subscriber"
require "rails/railtie"

module GraphQL
  class Client
    class Railtie < Rails::Railtie
      config.graphql = ActiveSupport::OrderedOptions.new
      config.graphql.client = GraphQL::Client.new

      # Eager load leaky dependency to workaround AS::Dependencies unloading issues
      #   https://github.com/rmosolgo/graphql-ruby/pull/240
      initializer "graphql.eager_load_hack" do |app|
        require "graphql"
        GraphQL::BOOLEAN_TYPE.name
      end

      initializer "graphql.configure_erb_implementation" do |app|
        require "graphql/client/erubis"
        ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubis
      end

      initializer "graphql.configure_views_namespace" do |app|
        require "graphql/client/view_module"
        Object.const_set(:Views, Module.new {
          extend GraphQL::Client::ViewModule
          self.path = "#{app.root}/app/views"
          self.client = config.graphql.client
        })
      end
    end
  end
end
