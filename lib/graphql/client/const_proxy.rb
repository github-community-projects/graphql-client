module GraphQL
  class Client
    # Internal: Hack to track the constant name an object is assigned to.
    #
    #   FooConstant = ConstProxy.new { |name|
    #     name # "FooConstant"
    #   }
    #
    module ConstProxy
      def self.new(&initializer)
        raise ArgumentError, "initializer required" unless block_given?

        Module.new do
          extend ConstProxy
          @initializer = initializer
        end
      end

      def name
        super || raise(RuntimeError, "expected object to be assigned to a constant")
      end

      def method_missing(*args, &block)
        @target ||= @initializer.call(self.name)
        @target.send(*args, &block)
      end
    end
  end
end
