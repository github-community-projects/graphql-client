Gem::Specification.new do |s|
  s.name = "graphql-client"
  s.version = "0.0.2"
  s.summary = "???"
  s.license = "MIT"

  s.files = Dir["README.md", "LICENSE", "lib/**/*.rb"]

  s.add_dependency "activesupport", ">= 3.0"
  s.add_dependency "graphql", "~> 0.17"

  s.add_development_dependency "minitest", "~> 5.9"
  s.add_development_dependency "rake", "~> 11.2"

  # s.required_ruby_version = ">= 2.3.0"

  s.authors = "GitHub"
end
