# Local Queries

Nothing says GraphQL queries need to go over wires.

If your frontend and backend code happen to be running in one big monolith application, you can simply point your client at your server's defined schema and execute queries in the same process.

```ruby
# server.rb
require "graphql"

module Server
  QueryType = GraphQL::ObjectType.define do
    name "Query"
    field :version, !types.Int
  end

  Schema = GraphQL::Schema.define(query: QueryType)
end
```

See more about [defining a server schema on the graphql-ruby guide](https://github.com/rmosolgo/graphql-ruby/blob/master/guides/defining_your_schema.md).

```ruby
# client.rb
require "server"
require "graphql/client"

Client = GraphQL::Client.new(schema: Server::Schema, execute: Server::Schema)

Query = Client.parse <<-'GRAPHQL'
  query {
    version
  }
GRAPHQL

result = Client.query(Query)
puts result.data.version
```
