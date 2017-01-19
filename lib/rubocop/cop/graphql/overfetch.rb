# frozen_string_literal: true
require "active_support/inflector"
require "graphql"
require "graphql/client/erubis"
require "rubocop"

module RuboCop
  module Cop
    module GraphQL
      # Public: Rubocop for catching overfetched fields in ERB templates.
      class Overfetch < Cop
        def_node_search :send_methods, "(send ...)"

        def investigate(processed_source)
          erb = File.read(processed_source.buffer.name)
          query, = ::GraphQL::Client::Erubis.extract_graphql_section(erb)
          return unless query

          aliases = {}
          fields = {}
          ranges = {}

          # TODO: Use GraphQL client parser
          document = ::GraphQL.parse(query.gsub(/::/, "__"))

          visitor = ::GraphQL::Language::Visitor.new(document)
          visitor[::GraphQL::Language::Nodes::Field] << ->(node, _parent) do
            name = node.alias || node.name
            fields[name] ||= 0
            field_aliases(name).each { |n| (aliases[n] ||= []) << name }
            ranges[name] ||= source_range(processed_source.buffer, node.line, 0)
          end
          visitor.visit

          send_methods(processed_source.ast).each do |node|
            _receiver, method_name, *_args = *node
            aliases.fetch(method_name.to_s, []).each do |field_name|
              fields[field_name] += 1
            end
          end

          fields.each do |field, count|
            next if count > 0
            add_offense(nil, ranges[field], "GraphQL field '#{field}' query but was not used in template.")
          end
        end

        def field_aliases(name)
          names = Set.new

          names << name
          names << "#{name}?"

          names << underscore_name = ActiveSupport::Inflector.underscore(name)
          names << "#{underscore_name}?"

          names
        end
      end
    end
  end
end
