# frozen_string_literal: true
require "active_support/inflector"
require "graphql"
require "graphql/client/view_module"
require "rubocop"

module RuboCop
  module Cop
    module GraphQL
      # Public: Rubocop for catching overfetched fields in ERB templates.
      class Overfetch < Base
        if defined?(RangeHelp)
          # rubocop 0.53 moved the #source_range method into this module
          include RangeHelp
        end

        def_node_search :send_methods, "({send csend block_pass} ...)"

        def investigate(processed_source)
          erb = File.read(processed_source.buffer.name)
          query, = ::GraphQL::Client::ViewModule.extract_graphql_section(erb)
          return unless query

          # TODO: Use GraphQL client parser
          document = ::GraphQL.parse(query.gsub(/::/, "__"))
          visitor = OverfetchVisitor.new(document) do |line_num|
            # `source_range` is private to this object,
            # so yield back out to it to get this info:
            source_range(processed_source.buffer, line_num, 0)
          end
          visitor.visit

          send_methods(processed_source.ast).each do |node|
            method_names = method_names_for(*node)

            method_names.each do |method_name|
              visitor.aliases.fetch(method_name, []).each do |field_name|
                visitor.fields[field_name] += 1
              end
            end
          end

          visitor.fields.each do |field, count|
            next if count > 0
            add_offense(visitor.ranges[field], message: "GraphQL field '#{field}' query but was not used in template.")
          end
        end

        class OverfetchVisitor < ::GraphQL::Language::Visitor
          def initialize(doc, &range_for_line)
            super(doc)
            @range_for_line = range_for_line
            @fields = {}
            @aliases = {}
            @ranges = {}
          end

          attr_reader :fields, :aliases, :ranges

          def on_field(node, parent)
            name = node.alias || node.name
            fields[name] ||= 0
            field_aliases(name).each { |n| (aliases[n] ||= []) << name }
            ranges[name] ||= @range_for_line.call(node.line)
            super
          end

          private

          def field_aliases(name)
            names = Set.new

            names << name
            names << "#{name}?"

            names << underscore_name = ActiveSupport::Inflector.underscore(name)
            names << "#{underscore_name}?"

            names
          end
        end


        def method_names_for(*node)
          receiver, method_name, *_args = node
          method_names = []

          method_names << method_name if method_name

          # add field accesses like `nodes.map(&:field)`
          method_names.concat(receiver.children) if receiver && receiver.sym_type?

          method_names.map!(&:to_s)
        end
      end
    end
  end
end
