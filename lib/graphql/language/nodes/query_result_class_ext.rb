require "graphql"
require "graphql/query_result"

module GraphQL
  module Language
    module Nodes
      # Internal: Common concerns between Nodes that have a "selections" collection.
      module Selections
        # Public: Get GraphQL::QueryResult class for result of query.
        #
        # Returns subclass of QueryResult or nil.
        def query_result_class(**kargs)
          return nil unless self.selections.any?
          GraphQL::QueryResult.define(fields: selections_query_result_classes(**kargs))
        end

        private
          # Internal: Gather QueryResult classes for each selection.
          #
          # Returns a Hash[String => (QueryResult|nil)].
          def selections_query_result_classes(**kargs)
            self.selections.inject({}) do |h, selection|
              h.merge!(selection.selection_query_result_classes(**kargs))
            end
          end
      end

      # Internal: Common concerns between Nodes that may be in a "selections" collection.
      module Selection
        def selection_query_result_classes(**kargs)
          raise NotImplementedError
        end
      end

      class Field < AbstractNode
        include Selection
        include Selections

        def selection_query_result_classes(**kargs)
          name = self.alias || self.name
          { name => query_result_class(**kargs) }
        end
      end

      class FragmentDefinition < AbstractNode
        include Selections
      end

      class FragmentSpread < AbstractNode
        include Selection

        def selection_query_result_classes(fragments: {}, **kargs)
          unless fragment = fragments[name.to_sym]
            raise ArgumentError, "missing fragment '#{name}'"
          end
          fragment.selection_query_result_classes(fragments: fragments, **kargs)
        end
      end

      class InlineFragment < AbstractNode
        include Selection
        include Selections

        def selection_query_result_classes(**kargs)
          if kargs[:shadow].include?(self)
            {}
          else
            selections_query_result_classes(**kargs)
          end
        end
      end

      class OperationDefinition < AbstractNode
        include Selections
      end
    end
  end
end
