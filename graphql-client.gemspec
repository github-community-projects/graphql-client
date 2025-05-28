# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = "graphql-client"
  s.version = "0.25.0"
  s.summary = "GraphQL Client"
  s.description = "A Ruby library for declaring, composing and executing GraphQL queries"
  s.homepage = "https://github.com/github-community-projects/graphql-client"
  s.license = "MIT"
  s.metadata = { "rubygems_mfa_required" => "true" }
  s.files = Dir["README.md", "LICENSE", "lib/**/*.rb"]

  s.add_dependency "activesupport", ">= 3.0"
  s.add_dependency "graphql", ">= 1.13.0"

  s.add_development_dependency "actionpack", ">= 3.2.22"
  s.add_development_dependency "erubi", "~> 1.6"
  s.add_development_dependency "erubis", "~> 2.7"
  s.add_development_dependency "minitest", "~> 5.9"
  s.add_development_dependency "rake", "~> 13.2.1"
  s.add_development_dependency "rubocop-github"
  s.add_development_dependency "rubocop", "~> 1.73.2"

  s.required_ruby_version = ">= 2.1.0"

  s.email = "engineering@github.com"
  s.authors = "GitHub"
end
