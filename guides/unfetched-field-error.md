# GraphQL::Client::UnfetchedFieldError

Raised when trying to access a field on a GraphQL response type which hasn't been explicitly queried.

```graphql
type User {
  firstName: String!
  lastName: String!
}
```

```ruby
UserFragment = Client.parse <<-'GRAPHQL'
  fragment on User {
    firstName
  }
GRAPHQL

user = UserFragment.new(user)

# ok
user.first_name

# raises UnfetchedFieldError, missing lastName field in query
user.last_name
```

GraphQL requires all fields to be explicitly queried. Just add `lastName` to your query and be on your way.

```ruby
UserFragment = Client.parse <<-'GRAPHQL'
  fragment on User {
    firstName
    lastName
  }
GRAPHQL

user = UserFragment.new(user)

# now ok!
user.last_name
```
