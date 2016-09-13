# graphql-client

## Installation

Add this line to your application's Gemfile:

    gem 'graphql-client'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install graphql-client

## Usage

To work with the client, you'll need to pass two variables to the initializer:

* You'll need to have access to a GraphQL schema. This can either be a JSON blob or simply a JSON file. Usually, you can generate this by executing an introspection query to a GraphQL server.
* You can optionally define a method that executes your schema. Usually, this is going to be some kind of HTTP adapter.

Once you've got that, you can set up the client like this:

``` ruby
HTTPAdapter = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
  def headers(context)
    {
      "Authorization" => "Bearer #{ENV['SECRET_TOKEN']}"
    }
  end
end

# passing schema as a string
schema = load_schema
client = GraphQL::Client.new(
  schema: schema,
  execute: HTTPAdapter
)

# passing schema as a file
client = GraphQL::Client.new(
  schema: "schema.json",
  execute: HTTPAdapter
)
```

Then, all you'll need to do is pass your GraphQL query to `client.query` to fetch the response.

You can also call `client.parse` on a query to generate a validation against the GraphQL query.
