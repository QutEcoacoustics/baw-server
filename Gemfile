source 'https://rubygems.org'

# Available groups:
# development - only for local dev machines
# production - for server deploys (includes staging)
# test - for running tests

# http://ryanbigg.com/2011/01/why-you-should-run-bundle-update/

# Gems required in all environments and all platforms
# ====================================================

# RAILS
# -------------------------------------

gem 'rails', '~> 4.2.2'
gem 'rack-cors', '~> 0.4.0', require: 'rack/cors'
gem 'responders', '~> 2.1.0'

# RAILS 3 compatibility gems
# -------------------------------------
# gem 'protected_attributes'
# gem 'rails-observers'
# gem 'actionpack-page_caching'
# gem 'actionpack-action_caching'
# gem 'activerecord-deprecated_finders'
gem 'activesupport-json_encoder', github: 'rails/activesupport-json_encoder'

# UI HELPERS
# -------------------------------------
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0.3'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12.1', platforms: :ruby, require: 'v8'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.0.0'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.3.0'

gem 'haml', '~> 4.0.6'
gem 'haml-rails', '~> 0.9.0'

gem 'simple_form', '~> 3.1.0'
gem 'paperclip', '~> 4.3.0'
gem 'breadcrumbs_on_rails', '~> 2.3.0'
# kept below version 2 due to huge breaking changes
gem 'gmaps4rails', '< 2'

# https://github.com/seyhunak/twitter-bootstrap-rails
# huge changes since last release (2.2.8 in Aug 2013), and not sure about rails 3.2 vs 4 support.
# used these commands to get lists of commits, then compared the commits to find the most recent matching commit
# git grep --full-name --name-only 'bootstrap-affix.js v2.3.2' $(git rev-list --all) > tbsr-2.3.2-find.txt
# git grep --full-name --name-only '.fa-play' $(git rev-list --all) > font-awesome-find.txt

# Don't update this, as site still uses bootstrap v2. Need to update this when bootstrap is updated.
# https://github.com/seyhunak/twitter-bootstrap-rails/tree/38476dbd7f9a99179388bffb101826d844029949
gem 'twitter-bootstrap-rails', git: 'https://github.com/seyhunak/twitter-bootstrap-rails.git', branch: :master, ref: '38476dbd7f'

gem 'bootstrap-timepicker-rails', '~> 0.1.3'
gem 'bootstrap-datepicker-rails', '~> 1.4.0'
# for rails 3, 4
gem 'will_paginate', '~> 3.0.7'
gem 'dotiw', '~> 3.0.1'
gem 'recaptcha', '~> 0.4.0', require: 'recaptcha/rails'

# for proper timezone support
gem 'tzinfo', '~> 1.2.2'
gem 'tzinfo-data', '~> 1.2015.1'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# http://joanswork.com/devise-3-1-update/
gem 'devise', '~> 3.5.1'
gem 'cancancan', '~> 1.12.0'
gem 'role_model', '~> 0.8.1'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.9'

# Database gems
# -------------------------------------
# don't change the database gems - causes:
# Please install the <db> adapter: `gem install activerecord-<db>-adapter` (<db> is not part of the bundle. Add it to Gemfile.)
gem 'pg', '~> 0.18.1'

# MODELS
# -------------------------------------
gem 'jc-validates_timeliness', '~> 3.1.1'

# https://github.com/delynn/userstamp
# no changes in a long time, and we are very dependant on how this works
# this might need to be changed to a fork that is maintained.
# No longer used - incorporated the gem's functionality directly.
#gem 'userstamp', git: 'https://github.com/theepan/userstamp.git'

gem 'enumerize', '~> 0.11.0'

gem 'uuidtools', '~> 2.1.5'
gem 'acts_as_paranoid', git: 'https://github.com/ActsAsParanoid/acts_as_paranoid.git', branch: :master, ref: 'ddcd191517'

# SETTINGS
# -------------------------------------
gem 'settingslogic', '~> 2.0.9'
require 'rbconfig'

# MONITORING
# -------------------------------------
gem 'exception_notification', '~> 4.1.0'
gem 'newrelic_rpm', '~> 3.12.0'

# Documentation & UI
# -------------------------------------
# these gems are required here to serve /doc url
gem 'rspec_api_documentation', '~> 4.4.0'
gem 'raddocs', '~> 0.4.0'

# MEDIA
# -------------------------------------
# set to a specific commit when releasing to master branch
gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git', branch: :master, ref: 'b0e285b15b'
gem 'rack-rewrite', '~> 1.5.1'

# ASYNC JOBS
# ------------------------------------
gem 'resque', '~> 1.25.2'
gem 'resque-job-stats', git: 'https://github.com/echannel/resque-job-stats.git', branch: :master, ref: '8932c036ae'
gem 'resque-status', '~> 0.5.0'
# set to a specific commit when releasing to master branch
gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git', branch: :master, ref: 'c88ae6f8b8'

# Gems restricted by environment and/or platform
# ====================================================

# gems that are only required on development machines or for testings
group :development, :test do
  gem 'quiet_assets'

  # capistrano gems
  gem 'capistrano', '~> 3.4.0'
  gem 'capistrano-bundler', '~> 1.1.3'
  gem 'capistrano-rvm', '~> 0.1.2'
  gem 'capistrano-rails', '~> 1.1.2'
  gem 'capistrano-newrelic', '~> 0.0.8'
  gem 'capistrano-passenger', '~> 0.1.0'

  gem 'rack-mini-profiler', '~> 0.9.2'
  gem 'rails-i18n-debug', '~> 1.0.1'
  gem 'bullet', '~> 4.14.1'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring', '~> 1.3.0'

  # Run `rails console` in the browser. Read more: https://github.com/rails/web-console
  #gem 'web-console', '~> 2.1.1'

  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', '~> 0.4.0'

  gem 'thin', '~> 1.6.3'

  gem 'notiffany', '~> 0.0.3'
  gem 'guard', '~> 2.12.1'
  gem 'guard-rspec', '~> 4.6.0'
  gem 'guard-yard', '~> 2.1.4', require: false
  gem 'rubocop', require: false
  gem 'haml-lint', require: false

  gem 'fakeredis', '~> 0.5.0', require: 'fakeredis/rspec'

  gem 'zonebie'

  # for cleaning up Rails apps
  # gem 'traceroute', require: false
  # gem 'scrap', require: false
  # gem 'rails_best_practices', require: false
  # gem 'rubocop', require: false
  # gem 'rubycritic', require: false
  # gem 'metric_fu', require: false

  # security checkers
  # gem 'codesake-dawn', require: false
  # gem 'brakeman', require: false

  # database checks
  # gem 'lol_dba', require: false
  # gem 'consistency_fail', require: false

  #gem 'debugger'
  # gem install traceroute --no-ri --no-rdoc

  gem 'rspec-rails', '~> 3.3.0'
  gem 'factory_girl_rails', '~> 4.5.0'
  gem 'capybara', '~> 2.4.4'

  gem 'rspec', '~> 3.3.0'
  gem 'simplecov', '~> 0.10.0', require: false
  gem 'shoulda-matchers', '~> 2.8.0'
  gem 'launchy', '~> 2.4.3'
  gem 'json_spec', '~> 1.1.4'
  gem 'database_cleaner', '1.4.1'
  gem 'webmock', '~> 1.21.0'
  gem 'coveralls', '~> 0.8.1', require: false
  gem 'codeclimate-test-reporter', '~> 0.4.5', require: nil
end