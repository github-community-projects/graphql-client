# frozen_string_literal: true
require "active_support/deprecation"

module GraphQL
  class Client
    if ActiveSupport::Deprecation.is_a?(Class)
      Deprecation = ActiveSupport::Deprecation.new("0.9", "graphql-client")
    else
      Deprecation = ActiveSupport::Deprecation
    end
  end
end
