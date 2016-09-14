# Remote Queries

In most GraphQL setups, the client will need to make some sort of network request to a remote server. Which will likely be HTTPS, which is why `GraphQL::Client` bundles a [basic HTTP adapter wrapping `Net::HTTP`](https://github.com/github/graphql-client/blob/master/lib/graphql/client/http.rb).

The stock `GraphQL::Client::HTTP` assumes your to a [express-graphql compatible endpoint](https://github.com/graphql/express-graphql#http-usage). There is no formal definition of what the HTTP endpoint should look like in the GraphQL spec itself, but the [express-graphql](https://github.com/graphql/express-graphql) service has become the de facto standard. It just assumes the endpoint accepts the following parameters: `"query"`, `"variables"` and `"operationName"`.

If you need to customize this, writing an adapter is very straight forward.

An execution adapter is any object that responds to `execute(document:, operation_name:, variables:, context:)`.

To demonstrate using a network library other than `Net::HTTP`, here's a simplified HTTP adapter using the Faraday library.

``` ruby
require "faraday"

class FaradayAdapter
  def self.execute(document:, operation_name:, variables:, context:)
    response = Faraday.post("http://graphql-swapi.parseapp.com/", {
      "query" => document.to_query_string,
      "operationName" => operation_name,
      "variables" => variables
    })
    JSON.parse(response.body)
  end
end
```
