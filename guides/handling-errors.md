# Handling Errors

There are two general types of GraphQL operation errors.

1. Parse or Validation errors
2. Execution errors

## Parse/Validation errors

Making a query to a server with invalid query syntax or against fields that don't exist will fail the entire operation. No data is returned.

``` ruby
response = Client.query(BadQuery)
response.data #=> nil
response.errors[:data] #=> "Field 'missing' doesn't exist on type 'Query'"
```

However, you're less likely to encounter these types of as since queries are validated locally on the client side before they are even sent. Ensure the `Client` instance is configured with the correct `GraphQL::Schema` and is up-to-date.

## Execution errors

Execution errors occur while the server if resolving the query operation. These errors may be the clients fault (like a HTTP 4xx), others could be a server issue (HTTP 5xx).

The errors API was modeled after [`ActiveModel::Errors`](http://api.rubyonrails.org/classes/ActiveModel/Errors.html). So it should be familiar if you're working with Rails.

``` ruby
class IssuesController < ApplicationController
  ShowQuery = FooApp::Client.parse <<-'GRAPHQL'
    query($id: ID!) {
      issue: node(id: $id) {
        ...Views::Issues::Show::Issue
      }
    }
  GRAPHQL

  def show
    # Always returns a GraphQL::Client::Response
    response = FooApp::Client.query(ShowQuery, variables: { id: params[:id] })

    # Response#data is nullable. In the case of nil, a well behaved server
    # will populate Response#errors with an explanation.
    if data = response.data

      # A Relay node() lookup is nullable so we should conditional check if
      # the id was found.
      if issue = data.issue
        render "issues/show", issue: issue      

      # Otherwise, the server will likely give us a message about why the node()
      # lookup failed.
      elsif data.errors[:issue].any?
        # "Could not resolve to a node with the global id of 'abc'"
        message = data.errors[:issue].join(", ")
        render status: :not_found, plain: message
      end

    # Parse/validation errors will have `response.data = nil`. The top level
    # errors object will report these.
    elsif response.errors.any?
      # "Could not resolve to a node with the global id of 'abc'"
      message = response.data.errors[:issue].join(", ")
      render status: :internal_server_error, plain: message
    end
  end
end
```

## Partial data sets

While validation errors never return any data to the client, execution errors have the ability to return partial data sets. The majority of a operation may be fulfilled, but slow calculation may have timed out or an internal service only a few fields could be down for maintenance.

Its important to remember that partial data being returned will still validate against the schema's type system. If a field is marked as non-nullable, it won't all the sudden come back `null` on a timeout. In this way, error handling becomes part of your existing nullable conditional checks. Forgetting to handle a error will graceful data to a "no data" case rather than causing an error.

### Nullable fields

An issue may or may not have an assignee. So we already need a guard to check if the value is present. In this case, we can also choose to look for errors loading the assignee.

``` erb
<% if issue.assignee %>
  <%= render "assignee", user: issue.assignee %>
<% elsif issue.errors[:assignee] %>
  <p>Something went wrong loading the assignee.</p>
<% end %>
```

### Default values

Scalar values that are non-nullable may return a sensible default value when there is an error fetching the data. Then set an error to inform the client that the data maybe wrong and they can choose to display it with a warning or not all all. If the client neglects to handle the error, the view can still be rendered with a default value.

``` erb
<% if repository.errors[:watchers_count].any? %>
  <img src="data-error.png">
<% end %>

<%= repository.watchers_count %> Watchers
```

### Empty or truncated collections

If an execution error occurs loading a collection of data, an empty list may be returned to the client.

``` erb
<% if repository.errors[:search_results].any? %>
  <p>Search is down</p>
<% else %>
  <% repository.search_results.nodes.each do |result| %>
    <%= result.title %>
  <% end %>
<% end %>
```

The list could also be partial populated and truncated because of a timeout.

``` erb
<% pull.diff_entries.nodes.each do |diff_entry| %>
  <%= diff_entry.path %>
<% end %>

<% if pull.errors[:diff_entries].any? %>
  <p>Sorry, we couldn't display all your diffs.</p>
<% end %>
```

## See also

* [graphql-js "path" field](https://github.com/graphql/graphql-js/blob/23592ad16868e06b1c003629759f905a77ab81a0/src/error/GraphQLError.js#L42-L48)
* [GraphQL Specification section on "Error handling"](https://facebook.github.io/graphql/#sec-Error-handling)
* [GraphQL Specification section on "Response errors"](https://facebook.github.io/graphql/#sec-Errors)
