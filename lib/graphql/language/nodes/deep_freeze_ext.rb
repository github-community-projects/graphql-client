# frozen_string_literal: true
require "graphql"

module GraphQL
  module Language
    module Nodes
      # :nodoc:
      class AbstractNode
        # Public: Freeze entire Node tree
        #
        # Returns self Node.
        def deep_freeze
          self.class.child_attributes.each do |attr_name|
            public_send(attr_name).freeze.each(&:deep_freeze)
          end

          self.class.scalar_attributes.each do |attr_name|
            object = public_send(attr_name)
            object.freeze if object
          end

          freeze
        end
      end
    end
  end
end
