# Heredoc style

Prefer quoted heredoc style when defining GraphQL query strings.

``` ruby
# good
FooQuery = <<-'GRAPHQL'
  { version }
GRAPHQL
```

``` ruby
# bad
FooQuery = <<-GRAPHQL
  { version }
GRAPHQL
```

Using a single quoted heredoc disables interpolation. GraphQL queries should not be constructed via string concatenate, especially at runtime. Interpolating user values into a query may lead to a "GraphQL injection" security vulnerability. Pass `variables:` instead of string interpolation.

``` ruby
# good
FooQuery = <<-'GRAPHQL'
  query($id: ID!) {
    node(id: $id) {
    }
  }
GRAPHQL
query(FooQuery, variables: { id: id })
```

``` ruby
# bad
FooQuery = <<-GRAPHQL
  query {
    node(id: "#{id}") {
    }
  }
GRAPHQL
query(FooQuery)
```

Bonus: Quoted heredocs syntax highlight look better in Atom.
