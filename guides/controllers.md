# Controllers

### Traditional Rails Controller responsibilities

* Enforce authentication, `before_filter :login_required`
* Load records from URL parameters, `Issue.find(params[:id])`
* Enforce resource authorization
* View specific association eager load optimizations, `includes(:comments, :labels)`
* Render template, JSON or redirect
* Update record from form parameters

### Platform Controllers

Controllers written with GraphQL queries will delegate all content authorization and record loading concerns to the GraphQL server. Actions will primarily be responsible for constructing a GraphQL query from the URL `params`, executing the query and passing the result data to a template or partial view.

```ruby
class IssuesController < ApplicationController
  # Statically define any GraphQL queries as constants. This avoids query string
  # parsing at runtime and ensures we can statically validate all queries for
  # errors.
  #
  # This defines how params data maps to a GraphQL query to find an Issue node.
  ShowQuery = FooApp::Client.parse <<-'GRAPHQL'
    query($user: String!, $repository: String!, number: Int!) {
      user(login: $user) {
        repository(name: $repository) {
          issue(number: $number) {
            ...Views::Issues::Show::Issue
          }
        }
      }
    }
  GRAPHQL

  def show
    # Execute our static query against URL params. All queries are executed in
    # the context of a "current_user".
    data = query ShowQuery, params.slice(:user, :repository, :number)

    # Check if the Issue node was found, if not the issue might not exist or
    # we just don't have permission to see it.
    if issue = data.user.repository.issue
      # Render the "issue/show" template with our data hash.
      render "issues/show", issue: issue
    else
      head :not_found
    end
  end
end
```

### Data is already scoped by viewer

The GraphQL API will not let the current user see or modify data they do not have access to. This obsoletes the need to do `before_filter :login_required` and scoped lookups. This authorization logic is implemented once by the API and not duplicated and scattered across multiple controllers.

The controller only needs to handle object existence and 404 when no data is returned.

### Data is tailored to specific view hierarchies

With ActiveRecord we could expose objects like `@repository` so any view could lazily traverse its attributes and associations. This object could be generically set by a `before_filter` and used freely by any subview. But this leads to unpredictable data access. Any one of these views could load traverse expense associations off this object.

Instead, views will explicitly declare their data dependencies. They'll only get the data they ask for. Its only useful to the view that requested it and therefore should be passed explicitly as a `:locals`. Also, actions within the same controller will be asking for different properties of the "repository" so having a shared `find_repository` before filter step no longer applies.

## See also

[github-graphql-rails-example](https://github.com/github/github-graphql-rails-example) template examples:

* [app/controller/repositories_controller.rb](https://github.com/github/github-graphql-rails-example/blob/master/app/controllers/repositories_controller.rb) defines the top level GraphQL queries to fetch repository list and show pages.
