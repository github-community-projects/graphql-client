# frozen_string_literal: true
require "active_support/deprecation"

module GraphQL
  class Client
    Deprecation = ActiveSupport::Deprecation.new("0.9", "graphql-client")
  end
end
