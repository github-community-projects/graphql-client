# frozen_string_literal: true
require "active_support/deprecation"

module GraphQL
  class Client
    if ActiveSupport::Deprecation.is_a?(Class)
      Deprecation = ActiveSupport::Deprecation.new("11.0", "graphql-client")
    else
      module Deprecation
        extend self

        def silence(&block)
          ActiveSupport::Deprecation.silence(&block)
        end

        def warn(*args)
          ActiveSupport::Deprecation.warn(*args)
        end
      end
    end
  end
end
