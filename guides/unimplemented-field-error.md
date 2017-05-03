# GraphQL::Client::UnimplementedFieldError

Raised when trying access a field on a GraphQL response type which isn't defined by the schema.

``` graphql
type User {
  name: String!
}
```

``` ruby
UserFragment = Client.parse <<-'GRAPHQL'
  fragment on User {
    name
  }
GRAPHQL

user = UserFragment.new(user)

# ok
user.name

# raises UnimplementedFieldError, no such field called nickname on User
user.nickname
```

It's possible the method name may just be a typo of an existing field.

Likely it's a field that you expected to be implemented but wasn't. If you own this schema, consider implementing it yourself!
