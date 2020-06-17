# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.

# If a future me is wondering why the Rails app gets booted twice when running
# `rails server`, then here is why:
#
# 1. The `rails` command boots the application to include tasks, routes, and
#    other metadata in the CLI commands.
# 2. The `rails server` command then runs  ~~and reuses the Rails.application instance~~.
#    This 'normal' case _would_ occur if we were using puma (the standard dev server).
# 3. Instead, passenger standalone receives the start command
# 4. The passenger process is entirely separate, thus the there is no shared memory,
#    cached requires, or already initialized `Rails.application` to reuse
# 5. Which brings us to this file, this comment, and this `puts` statement
# 6. And the rails application boots again!
#
# Note: the double boot does not occur if we simply use `passenger start` over
# `rails server`.

is_rails_server = defined?(Rails::Server)
puts 'baw-workbench: running rails server...' if is_rails_server
puts 'baw-workbench: booting passenger and web app...' unless is_rails_server

require "#{__dir__}/config/environment"
run Rails.application
