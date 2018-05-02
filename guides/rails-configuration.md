# Rails Configuration

Checkout the [GitHub GraphQL Rails example application](https://github.com/github/github-graphql-rails-example).

## Setup

Assumes your application is named `Foo`.

### Add graphql-client to your Gemfile

```ruby
gem 'graphql-client'
```

### Configure

This part is temporarily a mess due to railtie and application initialization order.

```ruby
require "graphql/client/railtie"
require "graphql/client/http"

module Foo
  HTTP = GraphQL::Client::HTTP.new("https://foo.com/")
  # TODO: Rails.root isn't available yet :(
  Client = GraphQL::Client.new(schema: "db/schema.json", execute: HTTP)

  class Application < Rails::Application
    # Set config.graphql.client to configure the client instance ERB templates
    # will be parsed against.
    #
    # client must be set before initializers run. config/initializers/*
    # are ran after graphql-client initializers so thats too late.
    config.graphql.client = Client
  end
end
```

### Define a schema updater rake task

_(May eventually be part of `graphql/railtie`)_

```ruby
namespace :schema do
  task :update do
    GraphQL::Client.dump_schema(Foo::HTTP, "db/schema.json")
  end
end
```

Its recommended you check in the downloaded schema. Periodically refetch and keep up-to-date.

```sh
$ bin/rake schema:update
$ git add db/schema.json
```
