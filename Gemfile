# frozen_string_literal: true
source "https://rubygems.org"
gemspec

rails_version = ENV["RAILS_VERSION"] == "edge" ? { github: "rails/rails" } : ENV["RAILS_VERSION"]
gem "actionpack", rails_version
gem "activesupport", rails_version

graphql_version = ENV["GRAPHQL_VERSION"] == "edge" ? { github: "rmosolgo/graphql-ruby", ref: "interpreter-without-legacy" } : ENV["GRAPHQL_VERSION"]
gem "graphql", graphql_version

group :development, :test do
  gem "rubocop", "~> 0.62.0"
end
