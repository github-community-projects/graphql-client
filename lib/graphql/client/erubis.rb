require "action_view"

module GraphQL
  class Client
    class Erubis < ActionView::Template::Handlers::Erubis
      # Ignore static <%graphql sections
      def convert_input(src, input)
        input = input.gsub(/<%graphql/, "<%#")
        super(src, input)
      end
    end
  end
end
