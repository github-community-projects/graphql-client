# Contributing to graphql-client

This project is the work of [many contributors](https://github.com/github-community-projects/graphql-client/graphs/contributors).
You're encouraged to submit [pull requests](https://github.com/github-community-projects/graphql-client/pulls)
and to [propose features and discuss issues](https://github.com/github-community-projects/graphql-client/issues).

In the examples below, substitute your GitHub username for `contributor` in URLs.

## Fork the Project

Fork the [project on GitHub](https://github.com/github-community-projects/graphql-client) and check out your copy.

```
git clone https://github.com/contributor/graphql-client.git
cd graphql-client
git remote add upstream https://github.com/github-community-projects/graphql-client.git
```

## Bundle Install and Test

Ensure that you can build the project and run the tests.

```
bundle install
bundle exec rake
```

The default Rake task runs the test suite **and** RuboCop. The project uses
**Minitest** (not RSpec) — keep new tests in that framework and style, alongside the
existing `test/test_*.rb` files.

## Create a Topic Branch

Keep your fork up to date and create a topic branch off `master` for your change.

```
git checkout master
git pull upstream master
git checkout -b my-feature-branch
```

## Write Tests

Add Minitest coverage for any behavior you change or add. Characterization tests that
pin existing behavior are especially welcome around the parser and fragment handling.
Run the full suite and RuboCop before pushing:

```
bundle exec rake
```

## Update the CHANGELOG

Add a line describing your change to the **Unreleased** section of `CHANGELOG.md`,
crediting yourself:

```
* [#123](https://github.com/github-community-projects/graphql-client/pull/123): Short description - [@contributor](https://github.com/contributor).
```

## Commit and Push Your Changes

Use clear commit messages. Keep the history focused — one logical change per branch.

```
git commit -am "Add my feature"
git push origin my-feature-branch
```

## Open a Pull Request

[Open a pull request](https://github.com/github-community-projects/graphql-client/compare)
from your topic branch against `master`. Describe the motivation and the change, and link
any related issues.

## Be Patient

Maintainers review on a best-effort basis. It's likely a reviewer will ask for changes —
that's a normal part of getting a contribution merged. Thanks for contributing!
