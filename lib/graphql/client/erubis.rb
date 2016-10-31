require "action_view"

module GraphQL
  class Client
    # Public: Extended Erubis implementation that supports GraphQL static
    # query sections.
    #
    #   <%graphql
    #     query GetVerison {
    #       version
    #     }
    #   %>
    #   <%= data.version %>
    #
    # Configure ActionView's default ERB implementation to use this class.
    #
    #   ActionView::Template::Handlers::ERB.erb_implementation = GraphQL::Client::Erubis
    #
    class Erubis < ActionView::Template::Handlers::Erubis
      # Public: Extract GraphQL section from ERB template.
      #
      # src - String ERB text
      #
      # Returns String GraphQL query and line number or nil or no section was
      # defined.
      def self.extract_graphql_section(src)
        query_string = src.scan(/<%graphql([^%]+)%>/).flatten.first
        return nil unless query_string
        [query_string, Regexp.last_match.pre_match.count("\n") + 1]
      end

      # Internal: Extend Rails' Erubis handler to simply ignore <%graphql
      # sections.
      def convert_input(src, input)
        input = input.gsub(/<%graphql/, "<%#")
        super(src, input)
      end
    end
  end
end
