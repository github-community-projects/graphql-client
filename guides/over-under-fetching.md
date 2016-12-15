# Over-fetching and under-fetching

In a dynamic language like Ruby, over and under fetching are two common pitfalls.

## Over-fetching

Over-fetching occurs when additional fields are declared in a fragment but are not actually used in the template. This will likely happen when template code is modified to remove usage of a certain field.

``` diff
  <%graphql
    fragment Issue on Issue {
      title
    }
  %>
- <h1><%= issue["title"] %></h1>
```

If the fragment is not updated along with this changed, the property will still be fetched when we no longer need it. A simple `title` field may not be a big deal in practice but this property could have been a more expensive nested data tree.

## Under-fetching

Under-fetching occurs when fields are not declared in a fragment but are used in the template. This missing data will likely surface as a `NoFieldError` or `nil` value.

Worse, there may be a latent under-fetch bug when a template does not declare a data dependency but appears to be working because its caller happens to fetch the correct data upstream. But when this same template is rendered from a different path, it errors on missing data.

``` erb
<%graphql
  fragment IssueHeader on Issue {
    title
    # forgot to declare
    # author { login }
  }
%>
<%= issue["title"] %>
by <%= issue["author"]["login"] %>
```

``` erb
<%graphql
  fragment Issue on Issue {
    number
    # parent view happens to include author.login the child will need
    author { login }
    ...Views::Issues::Issue::IssueHeader
  }
%>

<%= render "issue/header", issue: issue %>
```

The parent view in this case may drop its `author` dependency and break the child view.

``` diff
- # parent view happens to include author.login the child will need
- author { login }
```

## Data Masking

To avoid this under-fetching issue, views do not access raw JSON data directly. Instead they use a Ruby struct-like object derived from the fragment.

The `Views::Issues::Show::Issue.new` object wraps the raw data hash with accessors that are explicitly declared by the current view. Even though `issue["number"]` is fetched and exposed to the parent view, `issue.number` here will raise `NoFieldError`.

``` erb
<% issue = Views::Issues::Show::Issue.new(issue) %>
<%= issue.title %>
by <%= issue.author.login %>
```
