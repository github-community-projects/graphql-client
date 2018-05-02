# Templates

ERB templates access data in a similar way as traversing an ActiveRecord object graph. Simple object fields maybe accessed, as well as parent or child has-one and has-many associations.

All data passing is done explicitly through `locals:` just as you would pass arguments to a function. By convention, this object may be a raw data `Hash` received from GraphQL or a wrapped Ruby struct-like object. For consistency, the argument should be casted into a nice Ruby friendly object first thing in the template.

`app/views/issues/show.html.erb`:

```erb
<%# cast issue data hash into ruby friendly struct %>
<% issue = Issues::Show::Issue.new(issue) %>

<h1><%= issue.repository.name %>: <%= issue.title %></h1>
<%= issue.body_html # bodyHTML is snakecasified %>
by <%= issue.author.login %>

<% issue.comments.each do |comment| %>
  <%# Pass comment to subview %>
  <%= render "issues/comment", comment: comment %>
<% end %>
```

This is all pretty traditional Ruby and Rails so far.

However, since the views can not access ActiveRecord objects directly anymore, a static query is defined inline `.erb` file declaring the views data dependencies.

`app/views/issues/show.html.erb`:

```erb
<%graphql
  fragment on Issue {
    title
    repository {
      name
    }
    bodyHTML
    author {
      login
    }
    comments {
      # issues/show is only concerned with rendering a collection of
      # comments, not the comment itself. However, we do need to statically
      # include the data dependencies of the issues/comment partial we
      # intend to render.
      ...Views::Issues::Comment::Comment
    }
  }
%>
```

Our GraphQL fragment definition includes all the fields we want to access just in the `show.html.erb` file itself, nothing more, nothing less.

However, we do render a subview and hand off a `comment`. Since we composed rendered calls, we'll need to compose our fragment query as well. This works by including the subview's `...Views::Issues::Comment::Comment` into the
`comments` collection we requested.

`app/views/issues/_comment.html.erb`:

```erb
<%graphql
  fragment on Comment {
    bodyHTML
    author {
      login
    }
  }
%>

<%# cast comment data hash into ruby friendly struct %>
<%# this casting also allows us to accessing any fields that were opaque to %>
<%# our parent view. %>
<% comment = Issues::Comment::CommentFragment.new(comment) %>

<%= comment.body_html %>
by <%= comment.author.login %>
```

## Composing fragments

### Static

Many views will always render a set of subviews.

```erb
<div class="issue-container">
  <h1><%= issue.title %></h1>
  <%= render "issues/header", issue: issue %>
  <%= render "issues/body", issue: issue %>
</div>
```

The fragment should declare all the data dependencies used by just this partial. In this case, only the issue's `title` is explicitly used, then include any subview fragments.

```erb
<%graphql
  fragment IssueFragment on Issue {
    title
    ...Views::Issues::Header::Issue
    ...Views::Issues::Body::Issue
  }
%>
```

### Looping over a collection

```erb
<h1><%= issue.title %></h1>

<% issue.comments.each do |comment| %>
  <%= render "issues/comment", comment: comment %>
<% end %>
```

The fragment declares the view's own data dependencies as before. As well as the `comments` collection. Since a comment is passed to the `issues/comment` partial, not the issue, we'll include the fragment inside `comments { ... }`.

```erb
<%graphql
  fragment IssueFragment on Issue {
    title
    comments {
      ...Views::Issues::Comment::CommentFragment
    }
  }
%>
```

### Branch on associated data presence

```erb
<h1><%= issue.title %></h1>

<% if milestone = issue.milestone %>
  <%= render "issues/milestone", milestone: milestone
<% end %>
```

Similar to embedding a collection's fragment, the partial defines the data for the milestone itself, not the issue. We include the fragment in the `milestone { ... }` connection.

```erb
<%graphql
  fragment Issue on Issue {
    title
    milestone {
      ...Views::Issues::Milestone::Milestone
    }
  }
%>
```

### Branch on arbitrary flag

More generally, UI may only be visible if a flag is set on the data object.

```erb
<% if comment.editable_by_viewer? %>
  <%= render "issues/comment_edit_toolbar", comment: comment
<% end %>

<%= comment.body_html %>
```

Since the view may conditionally need the edit toolbars data, the view's fragment must always be included. This is an acceptable place where overfetching data is okay.

```erb
<%graphql
  fragment Comment on Comment {
    bodyHTML
    editableByViewer
    ...Views::Issues::CommentEditToolbar::Comment
  }
```

## See also

[github-graphql-rails-example](https://github.com/github/github-graphql-rails-example) template examples:

* [app/views/repositories/index.html.erb](https://github.com/github/github-graphql-rails-example/blob/master/app/views/repositories/index.html.erb) shows the root template's listing query and composition over subviews.
* [app/views/repositories/\_repositories.html.erb](https://github.com/github/github-graphql-rails-example/blob/master/app/views/repositories/_repositories.html.erb) makes use of GraphQL connections to show the first couple items and a "load more" button.
* [app/views/repositories/show.html.erb](https://github.com/github/github-graphql-rails-example/blob/master/app/views/repositories/show.html.erb) shows the root template for the repository show page.
