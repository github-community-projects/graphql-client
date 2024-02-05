# frozen_string_literal: true
require "active_support/log_subscriber"

module GraphQL
  class Client
    # Public: Logger for "*.graphql" notification events.
    #
    # Logs GraphQL queries to Rails logger.
    #
    #   UsersController::ShowQuery QUERY (123ms)
    #   UsersController::UpdateMutation MUTATION (456ms)
    #
    # Enable GraphQL Client query logging.
    #
    #   require "graphql/client/log_subscriber"
    #   GraphQL::Client::LogSubscriber.attach_to :graphql
    #
    class LogSubscriber < ActiveSupport::LogSubscriber
      SHOULD_USE_KWARGS = private_instance_methods.include?(:mode_from)

      def query(event)
        logger.info do
          name = event.payload[:operation_name].gsub("__", "::")
          type = event.payload[:operation_type].upcase

          if SHOULD_USE_KWARGS
            color("#{name} #{type} (#{event.duration.round(1)}ms)", nil, bold: true)
          else
            color("#{name} #{type} (#{event.duration.round(1)}ms)", nil, true)
          end
        end

        logger.debug do
          event.payload[:document].to_query_string
        end
      end

      def error(event)
        logger.error do
          name = event.payload[:operation_name].gsub("__", "::")
          message = event.payload[:message]

          if SHOULD_USE_KWARGS
            color("#{name} ERROR: #{message}", nil, bold: true)
          else
            color("#{name} ERROR: #{message}", nil, true)
          end
        end
      end
    end
  end
end
