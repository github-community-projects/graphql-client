# frozen_string_literal: true
require "graphql/client/errors"

module GraphQL
  class Client
    # Public: Array wrapper for value returned from GraphQL List.
    class List < Array
      def initialize(values, errors = Errors.new)
        super(values)
        @errors = errors
        freeze
      end

      # Public: Return errors associated with list of data.
      #
      # Returns Errors collection.
      attr_reader :errors
    end
  end
end
