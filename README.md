# graphql-client

## Usage

### Configuration

Sample configuration for a GraphQL Client to query from the [SWAPI GraphQL Wrapper](https://github.com/graphql/swapi-graphql).

``` ruby
require "graphql/client"
require "graphql/client/http"

# Star Wars API example wrapper
module SWAPI
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  HTTP = GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, its smart to dump this to a JSON file and load from disk
  #
  # Run in from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
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

Pass the reference of a parsed query definition to `GraphQL::Client#query`. Data is returned back in a wrapped `GraphQL::QueryResult` struct that provides Ruby-ish accessors.

``` ruby
result = SWAPI::Client.query(Hero::Query)

# The raw data is Hash of JSON values
# result["data"]["luke"]["homePlanet"]

# The wrapped result allows to you access data with Ruby methods
result.data.luke.home_planet
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
