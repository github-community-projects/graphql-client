# frozen_string_literal: true
source "https://rubygems.org"
gemspec

gem "actionpack", ENV["RAILS_VERSION"] if ENV["RAILS_VERSION"]
gem "activesupport", ENV["RAILS_VERSION"] if ENV["RAILS_VERSION"]
if ENV["GRAPHQL_VERSION"] == "1.8-dev"
  gem "graphql", github: "rmosolgo/graphql-ruby", branch: "1.8-dev"
elsif ENV["GRAPHQL_VERSION"]
  gem "graphql", ENV["GRAPHQL_VERSION"]
end


group :development, :test do
  gem "rubocop", "~> 0.51"
end
