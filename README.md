# graphql-client

GraphQL Client is a Ruby library for declaring, composing and executing GraphQL queries.

## Usage

### Configuration

Sample configuration for a GraphQL Client to query from the [SWAPI GraphQL Wrapper](https://github.com/graphql/swapi-graphql).

``` ruby
require "graphql/client"
require "graphql/client/http"

# Star Wars API example wrapper
module SWAPI
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  HTTP = GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/") do
    def headers(context)
      # Optionally set any HTTP headers
      { "User-Agent": "My Client" }
    end
  end  

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end

# Let the application know where your client is
Rails.application.config.graphql.client = SWAPI::Client
```

You want to make sure somewhere in your application you tell GraphQL::Client where your configured GraphQL::Client is. For example:

```
Rails.application.config.graphql.client = Application::Client
```

If you already have a GraphQL schema defined in your application you can run the provided generator to configure your application to use GraphQL::Client:

```
$ rails generate graphql_client:install
```

### Defining Queries

If you haven't already, [familiarize yourself with the GraphQL query syntax](http://graphql.org/docs/queries/). Queries are declared with the same syntax inside of a `<<-'GRAPHQL'` heredoc. There isn't any special query builder Ruby DSL.

This client library encourages all GraphQL queries to be declared statically and assigned to a Ruby constant.

``` ruby
HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
  query {
    hero {
      name
    }
  }
GRAPHQL
```
Queries can reference variables that are passed in at query execution time.

```ruby
HeroFromEpisodeQuery = SWAPI::Client.parse <<-'GRAPHQL'
  query($episode: Episode) {
    hero(episode: $episode) {
      name
    }
  }
GRAPHQL
```

Fragments are declared similarly.

``` ruby
HumanFragment = SWAPI::Client.parse <<-'GRAPHQL'
  fragment on Human {
    name
    homePlanet
  }
GRAPHQL
```

To include a fragment in a query, reference the fragment by constant.

``` ruby
HeroNameQuery = SWAPI::Client.parse <<-'GRAPHQL'
  {
    luke: human(id: "1000") {
      ...HumanFragment
    }
    leia: human(id: "1003") {
      ...HumanFragment
    }
  }
GRAPHQL
```

This works for namespaced constants.

``` ruby
module Hero
  Query = SWAPI::Client.parse <<-'GRAPHQL'
    {
      luke: human(id: "1000") {
        ...Human::Fragment
      }
      leia: human(id: "1003") {
        ...Human::Fragment
      }
    }
  GRAPHQL
end
```

`::` is invalid in regular GraphQL syntax, but `#parse` makes an initial pass on the query string and resolves all the fragment spreads with [`constantize`](http://api.rubyonrails.org/classes/ActiveSupport/Inflector.html#method-i-constantize).

### Executing queries

Pass the reference of a parsed query definition to `GraphQL::Client#query`. Data is returned back in a wrapped `GraphQL::Client::Schema::ObjectType` struct that provides Ruby-ish accessors.

``` ruby
result = SWAPI::Client.query(Hero::Query)

# The raw data is Hash of JSON values
# result["data"]["luke"]["homePlanet"]

# The wrapped result allows to you access data with Ruby methods
result.data.luke.home_planet
```
`GraphQL::Client#query` also accepts variables and context parameters that can be leveraged by the underlying network executor.

``` ruby
result = SWAPI::Client.query(Hero::HeroFromEpisodeQuery, variables: {episode: "JEDI"}, context: {user_id: current_user_id})
```
### Rails ERB integration

If you're using Ruby on Rails ERB templates, theres a ERB extension that allows static queries to be defined in the template itself.

```erb
<%# app/views/humans/human.html.erb %>
<%graphql
  fragment HumanFragment on Human {
    name
    homePlanet
  }
%>

<%# You must use the fragment you created above before accessing the data. %>
<%- human = Views::Humans::Human::HumanFragment.new(human) %>

<p><%= human.name %> lives on <%= human.home_planet %>.</p>
```

These `<%graphql` sections are simply ignored at runtime but make their definitions available through constants.  In this case we named it `HumanFragment` which means it can be accessed at `Views::Humans::Human::HumanFragment`. If you named it `HumanInformationFragment` you could access it at `Views::Humans::Human::HumanInformationFragment`. The name of the fragment can be anything you like.

How is the `Views::Humans::Human` part of the class name determined? The namespacing is derived from the `.erb`'s path the fragment was defined in plus the fragment name.

```
>> "views/humans/human".camelize
=> "Views::Humans::Human"
>> Views::Humans::Human::HumanFragment
=> #<GraphQL::Client::FragmentDefinition>
```

Now that we have the query defined in the view, we can reference it in the controller and actually execute the GraphQL query:

```ruby
class HomeController < ApplicationController
  IndexQuery = graphql_parse <<-'GRAPHQL'
  query($humanId: String!) {
    human(id: $humanId) {
      ...Views::Home::Index::HomeFragment
    }
  }
  GRAPHQL
  def index
    variables = {
      humanId: "1002",
    }
    characters = graphql_query(IndexQuery, variables)
    render "index", locals: { characters: characters }
  end
end
```

Should your query generate any errors it will raise a `GraphQL::Client::QueryError` exception.

If you're wondering why the special ERB extension exists, in standard Ruby you can simply assign queries and fragments to constants and they'll be available throughout the app. However, the contents of an ERB template is compiled into a Ruby method, and methods can't assign constants. So a new ERB tag was extended to declare static sections that include a GraphQL query.

## Extending the query context

After you run the [provided Rails generator](#configuration) it will add a `graphql_context` method for you to use to pass any additional context for your queries.

For example:

```ruby
class ApplicationController < ActionController::Base
  def graphql_context
    {
      request_id: request.request_id,
    }
  end
end
```

You could now access any of these fields in your GraphQL schema:

```ruby
field :login, types.String do
  description "An example field added by the generator"
  resolve ->(obj, args, ctx) {
    ctx[:viewer]&.login
  }
end
```

## Examples

[github/github-graphql-rails-example](https://github.com/github/github-graphql-rails-example) is an example application using this library to implement views on the GitHub GraphQL API.

## Installation

Add `graphql-client` to your app's Gemfile:

``` ruby
gem 'graphql-client'
```

## See Also

* [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) gem which implements 80% of what this library provides. ❤️ [@rmosolgo](https://github.com/rmosolgo)
* [Facebook's GraphQL homepage](http://graphql.org/)
* [Facebook's Relay homepage](https://facebook.github.io/relay/)
