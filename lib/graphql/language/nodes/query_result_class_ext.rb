require "graphql"
require "graphql/language/nodes/selection_ext"
require "graphql/client/query_result"
require "set"

module GraphQL
  module Language
    module Nodes
      module Selections
        # Public: Get GraphQL::QueryResult class for result of query.
        #
        # Returns subclass of QueryResult or nil.
        def query_result_class(**kargs)
          GraphQL::Client::QueryResult.define(fields: selections_query_result_classes(**kargs))
        end

        def selection_query_result_classes(**kargs)
          selections_query_result_classes(**kargs)
        end

        # Internal: Gather QueryResult classes for each selection.
        #
        # Returns a Hash[String => (QueryResult|nil)].
        def selections_query_result_classes(shadow: Set.new, **kargs)
          self.selections.inject({}) do |h, selection|
            case selection
            when Selection
              if shadow.include?(selection)
                h
              else
                h.merge!(selection.selection_query_result_classes(shadow: shadow, **kargs))
              end
            else
              raise TypeError, "expected selection to be of type Selection, but was #{selection.class}"
            end
          end
        end
      end

      class Field < AbstractNode
        # Public: Get GraphQL::QueryResult class for result of query.
        #
        # Returns subclass of QueryResult or nil.
        def query_result_class(**kargs)
          if self.selections.any?
            super
          else
            nil
          end
        end

        def selection_query_result_classes(**kargs)
          name = self.alias || self.name
          { name => query_result_class(**kargs) }
        end
      end

      class FragmentSpread < AbstractNode
        def selection_query_result_classes(fragments: {}, shadow: Set.new, **kargs)
          unless fragment = fragments[name.to_sym]
            raise ArgumentError, "missing fragment '#{name}'"
          end
          return {} if shadow.include?(fragment)
          fragment.selection_query_result_classes(fragments: fragments, shadow: shadow, **kargs)
        end
      end
    end
  end
end
