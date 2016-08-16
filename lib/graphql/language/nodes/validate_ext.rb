require "graphql"

module GraphQL
  class ValidationError < GraphQL::ExecutionError
  end

  module Language
    module Nodes
      class Document < AbstractNode
        def validate!(schema:, rules: StaticValidation::ALL_RULES)
          validator = StaticValidation::Validator.new(schema: schema, rules: rules)
          query = Query.new(schema, document: self)

          validator.validate(query).fetch(:errors).each do |error|
            raise ValidationError, error["message"]
          end

          nil
        end
      end

      class FragmentDefinition < AbstractNode
        def validate!(schema:, **kargs)
          document = Document.new(definitions: [self])
          rules = StaticValidation::ALL_RULES - [StaticValidation::FragmentsAreUsed]
          document.validate!(schema: schema, rules: rules, **kargs)
        end
      end

      class OperationDefinition < AbstractNode
        def validate!(schema:, **kargs)
          document = Document.new(definitions: [self])
          document.validate!(schema: schema, **kargs)
        end
      end

      class InlineFragment < AbstractNode
        def validate!(schema:, **kargs)
          fragment = FragmentDefinition.new(name: "FooFragment", type: self.type, directives: self.directives, selections: self.selections)
          fragment.validate!(schema: schema, **kargs)
        end
      end
    end
  end
end
