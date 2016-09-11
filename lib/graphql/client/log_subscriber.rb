require "active_support/log_subscriber"

module GraphQL
  class Client
    # Public: Logger for "*.graphql" notification events.
    #
    # Logs GraphQL queries to Rails logger.
    #
    #   QUERY (123ms) UsersController::ShowQuery
    #   MUTATION (456ms) UsersController::UpdateMutation
    #
    # Enable GraphQL Client query logging.
    #
    #   require "graphql/client/log_subscriber"
    #   GraphQL::Client::LogSubscriber.attach_to :graphql
    #
    class LogSubscriber < ActiveSupport::LogSubscriber
      def query(event)
        # TODO: Colorize output
        info { "#{event.payload[:operation_type].upcase} (#{event.duration.round(1)}ms) #{event.payload[:operation_name].gsub("__", "::")}" }
        debug { event.payload[:document].to_query_string }
      end
    end
  end
end
