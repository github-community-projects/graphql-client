# frozen_string_literal: true
source "https://rubygems.org"
gemspec

gem "actionpack", ENV["RAILS_VERSION"] if ENV["RAILS_VERSION"]
gem "activesupport", ENV["RAILS_VERSION"] if ENV["RAILS_VERSION"]
gem "graphql", ENV["GRAPHQL_VERSION"] if ENV["GRAPHQL_VERSION"]

group :development, :test do
  gem "rubocop", "~> 0.51"
end
