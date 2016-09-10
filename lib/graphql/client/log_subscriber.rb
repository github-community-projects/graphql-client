require "active_support/log_subscriber"

module GraphQL
  class Client
    class LogSubscriber < ActiveSupport::LogSubscriber
      def query(event)
        info { "#{event.payload[:name]} (#{event.duration.round(1)}ms) #{event.payload[:operation_name].gsub("__", "::")}" }
        debug { event.payload[:document].to_query_string }
      end
    end
  end
end

GraphQL::Client::LogSubscriber.attach_to :graphql
