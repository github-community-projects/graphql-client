# Collocated Call Sites

The collocation best practice comes from the [Relay.js](https://facebook.github.io/relay/) library where GraphQL queries and views always live side by side to make it possible to reason about isolated components of an application. Both the query and display form one highly cohesive unit. Callers are decoupled from the data dependencies the function requires.

## Ruby method collocation

``` ruby
PageTitleFragment = SWAPI::Client.parse <<-'GRAPHQL'
  fragment on Human {
    name
    homePlanet
  }
GRAPHQL

def page_title(human)
  human = PageTitleFragment.new(human)

  tag(:title, "#{human.name} from #{human.home_planet}")
end
```

Both the fragment definition and helper logic are side by side as a single cohesive unit. This is a one to one relationship. A fragment definition should only be used by one helper method.

You can clearly see that both `name` and `homePlanet` are used by this helper method and no extra fields have been queried or used at runtime.

Additional fields maybe queried without any change to this functions call sites.

``` diff
  PageTitleFragment = SWAPI::Client.parse <<-'GRAPHQL'
    fragment on Human {
      name
-     homePlanet
+     age
    }
  GRAPHQL

  def page_title(human)
    human = PageTitleFragment.new(human)

    tag(:title, "#{human.name} is #{human.age} years old")
  end
```

## ERB Collocation

``` erb
<%graphql
  fragment Human on Human {
    name
    homePlanet
  }
%>
<% human = Views::Humans::Show::Human.new(human) %>

<title><%= human.name %> from <%= human.home_planet %></title>
```

Since ERB templates can not define static constants, a special `<%graphql` section tag provides a way to declare a fragment for the template.

As with the plain old ruby method, you can still clearly see that both `name` and `homePlanet` are used by this template and no extra fields have been queried or used at runtime.

## Pitfalls

### Sharing definitions between multiple helpers

``` ruby
# bad
SharedFragment = SWAPI::Client.parse <<-'GRAPHQL'
  fragment on Human {
    name
    homePlanet
  }
GRAPHQL

def human_header(human)
  human = SharedFragment.new(human)

  content_tag(:h1, human.name.capitalize)
end

def page_title(human)
  human = SharedFragment.new(human)

  content_tag(:title, "#{human.name} from #{human.home_planet}")
end
```

While the `page_title` uses both `name` and `homePlanet` fields, `human_header` only uses `name`. This means any caller of `human_header` must unnecessarily fetch the data for `homePlanet`. This is an example of "over-fetching".

Avoid this by defining separate fragments for `human_header` and `page_title`.

### Sharing object references with logic outside the current module

``` erb
<%graphql
  fragment Human on Human {
    name
    homePlanet
  }
%>
<% human = Views::Humans::Show::Human.new(human) %>

<%= page_title(human) %>
```

Just looking at this template it appears that none of the fields queried are actually used. But until we dig into the helper methods do we see they are implicitly accessed by other logic. This breaks our ability to locally reason about the template data requirements.

``` ruby
# bad
def page_title(human)
  page_title_via_more_indirection(human)
end

# bad
def page_title_via_more_indirection(human)
  tag(:title, "#{human.name} from #{human.home_planet}")
end
```

Instead, declare and explicitly include the dependencies for helper methods that many receive GraphQL data objects. This decouples the `page_title` from changes to the ERB `Human` fragment.

``` erb
<%graphql
  fragment Human on Human {
    ...HumanHelper::PageTitleFragment
  }
%>
<% human = Views::Humans::Show::Human.new(human) %>

<%= page_title(human) %>
```

``` ruby
PageTitleFragment = SWAPI::Client.parse <<-'GRAPHQL'
  fragment on Human {
    name
    homePlanet
  }
GRAPHQL

def page_title(human)
  tag(:title, "#{human.name} from #{human.home_planet}")
end
```

## See Also

* [Over-fetching and under-fetching](over-under-fetching.md)
