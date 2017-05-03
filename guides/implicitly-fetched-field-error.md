# GraphQL::Client::ImplicitlyFetchedFieldError

Similar to [`UnfetchedFieldError`](unfetched-field-error.md), but raised when trying to access a field on a GraphQL response type that happens to be fetched elsewhere by another fragment but not by the current fragment. The data is available, but isn't safe to rely on until it is explicitly added to the fragment.

This protection is similar to [Relay's Data Masking feature](https://facebook.github.io/relay/docs/thinking-in-relay.html#data-masking).

## Parent Data Leak

One source of these data leak may come from a parent fragment fetching the data used down in a nested subview.

For instance, a controller may fetch a user and include its `fullName`.

``` ruby
UserQuery = Client.parse <<-'GRAPHQL'
  query {
    user(name: "Josh") {
      fullName
      ...Views::Users::Show::User
    }
  }
GRAPHQL
```

Many layers deep, a contact info helper might also too want to make use of the user's `fullName`.

``` ruby
UserFragment = Client.parse <<-'GRAPHQL'
  fragment on User {
    location
    # forgot fullName
  }
GRAPHQL

user = UserFragment.new(user)

# ok as `age` was explicitly queried
user.location

# raises UnfetchedFieldError, missing fullName field in query
user.full_name
```

In this case, the raw GraphQL will include both `location` and `fullName`:

``` json
{
  "user": {
    "fullName": "Joshua Peek",
    "location": "Chicago"
  }
}
```

If the controller for some reason decides its doesn't care about `fullName` anymore and stops querying it, it will break the helper. The developer just looking at that controller file isn't going to know some other helper on the other side of the codebase still cares about `fullName`.

Self contained functions should only safely rely on data dependencies they explicitly ask for. If both the controller and our helper explicitly state they both need `fullName`, that data will always be fetched even if the data requirements for one of the functions changes.

## Child Data Leak

Similar to the parent data leak scenario, but occurs when a subview fetches data that our root view didn't explicitly ask for.

``` erb
<%graphql
  fragment User on User {
    fullName
    location
  }
%>
```

``` ruby
UserQuery = Client.parse <<-'GRAPHQL'
  query {
    user(name: "Josh") {
      ...Views::Users::Show::User
    }
  }
GRAPHQL

user = UserQuery.new(data)

# raises UnfetchedFieldError, missing fullName field in query
user.full_name
```

The raw flattened data will include `fullName` just like the previous example. But again, we should depend on our `UserQuery` always having `fullName` available show the subview be modified.

## See Also

* [Over-fetching and under-fetching](over-under-fetching.md)
* [Relay Data Masking](https://facebook.github.io/relay/docs/thinking-in-relay.html#data-masking)
