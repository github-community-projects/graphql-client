# frozen_string_literal: true
require "graphql/client/error"

module GraphQL
  class Client

    # Collocation will not be enforced if a stack trace includes any of these gems.
    WHITELISTED_GEM_NAMES = %w{pry byebug}

    # Raised when method is called from outside the expected file scope.
    class NonCollocatedCallerError < Error; end

    # Enforcements collocated object access best practices.
    module CollocatedEnforcement
      extend self

      # Public: Ignore collocated caller enforcement for the scope of the block.
      def allow_noncollocated_callers
        Thread.current[:query_result_caller_location_ignore] = true
        yield
      ensure
        Thread.current[:query_result_caller_location_ignore] = nil
      end

      def verify_collocated_path(location, path, method = "method")
        return yield if Thread.current[:query_result_caller_location_ignore]

        if (location.path != path) && !(WHITELISTED_GEM_NAMES.any? { |g| location.path.include?("gems/#{g}") })
          error = NonCollocatedCallerError.new("#{method} was called outside of '#{path}' https://git.io/v1syX")
          error.set_backtrace(caller(2))
          raise error
        end

        begin
          Thread.current[:query_result_caller_location_ignore] = true
          yield
        ensure
          Thread.current[:query_result_caller_location_ignore] = nil
        end
      end

      # Internal: Decorate method with collocated caller enforcement.
      #
      # mod - Target Module/Class
      # methods - Array of Symbol method names
      # path - String filename to assert calling from
      #
      # Returns nothing.
      def enforce_collocated_callers(mod, methods, path)
        mod.prepend(Module.new do
          methods.each do |method|
            define_method(method) do |*args, &block|
              location = caller_locations(1, 1)[0]
              CollocatedEnforcement.verify_collocated_path(location, path, method) do
                super(*args, &block)
              end
            end
          end
        end)
      end
    end
  end
end
