module GraphQL
  class Client
    # Public: Array wrapper for value returned from GraphQL List.
    class List < Array
      def initialize(values, path = [], errors = [])
        @ast_path = path
        @all_errors = Errors.filter_path(errors || [], @ast_path)
        @errors = Errors.find_path(errors || [], @ast_path)
        super(values)
        freeze
      end

      attr_reader :ast_path
      attr_reader :errors
      attr_reader :all_errors
    end
  end
end
