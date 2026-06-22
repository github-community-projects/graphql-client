# frozen_string_literal: true
source "https://rubygems.org"
gemspec

rails_version = ENV["RAILS_VERSION"] == "edge" ? { github: "rails/rails" } : ENV["RAILS_VERSION"]
gem "actionpack", rails_version
gem "activesupport", rails_version
gem "concurrent-ruby", "1.3.4"

# i18n 1.15.0 uses Fiber[] (fiber storage), which only exists on Ruby 3.2+.
# On older Rubies it installs but crashes at require time with
# "undefined method `[]' for Fiber:Class", taking down the whole suite before
# any test runs. Keep pre-3.2 Rubies on the 1.14.x line.
gem "i18n", "< 1.15" if RUBY_VERSION < "3.2"

graphql_version = ENV["GRAPHQL_VERSION"] == "edge" ? { github: "rmosolgo/graphql-ruby", ref: "interpreter-without-legacy" } : ENV["GRAPHQL_VERSION"]
gem "graphql", graphql_version

group :development, :test do
  gem "debug", ">= 1.0.0"
end
