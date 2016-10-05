module GraphQL
  class Client
    # Public: Array wrapper for value returned from GraphQL List.
    class List < Array
      def initialize(values, path = [], _errors = [])
        @ast_path = path

        # TODO: Implement List errors
        @all_errors = Errors.new([])
        @errors = Errors.new([])

        super(values)
        freeze
      end

      attr_reader :ast_path
      attr_reader :errors
      attr_reader :all_errors
    end
  end
end
