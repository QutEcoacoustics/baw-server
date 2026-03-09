# Copilot instructions

## Running commands

In this solution you do not need to use `bundle exec` when running commands. You can just run `rspec` instead of `bundle exec rspec`. This is because the project uses `bundler/setup` in the `spec_helper.rb` file, which sets up the load path for the gems specified in the Gemfile. This allows you to run commands without needing to prefix them with `bundle exec`.

You also do not need to `cd` into the `baw-server` directory to run commands.
New terminal's *should* default to the `baw-server` directory.

## Test env

We have a helper called `test-env` that sets the `RAILS_ENV` to `test`.

## Running migrations

Because we're in a container that has `RAILS_ENV=development` by default, rails won't run migrations for the test env.
So to keep things in sync you should run migrations like this:

```bash
rails db:migrate && test-env rails db:migrate
# and to rollback
rails db:rollback && test-env rails db:rollback
```
