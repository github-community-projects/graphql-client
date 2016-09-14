# graphql-client

## Usage

To work with the client, you'll need to pass two variables to the initializer:

* You'll need to have access to a GraphQL schema. This can either be a JSON blob or simply a JSON file. Usually, you can generate this by executing an introspection query to a GraphQL server.
* You can optionally define a method that executes your schema. Usually, this is going to be some kind of HTTP adapter.

Once you've got that, you can set up the client like this:

``` ruby
require "graphql/client"

module SWAPI
  HTTP = GraphQL::Client::HTTP.new("http://graphql-swapi.parseapp.com/")

  # Fetch latest schema on boot,
  Schema = GraphQL::Client.load_schema(HTTP)
  # However, its smart to dump this to a JSON file and load from disk
  #
  # GraphQL::Client.dump_schema(HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
```

Then, all you'll need to do is pass your GraphQL query to `SWAPI::Client.query` to fetch the response.

You can also call `SWAPI::Client.parse` on a query to generate a validation against the GraphQL query.

## Installation

Add `graphql-client` to your app's Gemfile:

``` ruby
gem 'graphql-client'
```

## See Also

* [graphql-ruby](https://github.com/rmosolgo/graphql-ruby) gem which supports 90% of the features this library provides. ❤️ @rmosolgo
