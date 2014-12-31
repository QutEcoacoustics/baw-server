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

gem 'rails', '~> 4.2.0'
gem 'rack-cors', '~> 0.3.1', require: 'rack/cors'
gem 'responders', '~> 2.0'

# RAILS 3 compatibility gems
# -------------------------------------
# gem 'protected_attributes'
# gem 'rails-observers'
# gem 'actionpack-page_caching'
# gem 'actionpack-action_caching'
# gem 'activerecord-deprecated_finders'
# gem 'activesupport-json_encoder', github: 'rails/activesupport-json_encoder'

# UI HELPERS
# -------------------------------------
# Use SCSS for stylesheets
gem 'sass-rails'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.1.0'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer',  platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'

gem 'haml'
gem 'haml-rails'

gem 'simple_form' #https://github.com/plataformatec/simple_form
gem 'paperclip'
gem 'breadcrumbs_on_rails'
# kept below version 2 due to huge breaking changes
gem 'gmaps4rails', '< 2'

# https://github.com/seyhunak/twitter-bootstrap-rails
# huge changes since last release (2.2.8 in Aug 2013), and not sure about rails 3.2 vs 4 support.
# used these commands to get lists of commits, then compared the commits to find the most recent matching commit
# git grep --full-name --name-only 'bootstrap-affix.js v2.3.2' $(git rev-list --all) > tbsr-2.3.2-find.txt
# git grep --full-name --name-only '.fa-play' $(git rev-list --all) > font-awesome-find.txt
gem 'twitter-bootstrap-rails', git: 'https://github.com/seyhunak/twitter-bootstrap-rails.git', ref: '38476dbd7f'

gem 'bootstrap-timepicker-rails'
gem 'bootstrap-datepicker-rails'
# for rails 3, 4
gem 'will_paginate'
gem 'dotiw', git: 'https://github.com/radar/dotiw.git', ref: 'e01191d'
gem 'recaptcha',  require: 'recaptcha/rails'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# http://joanswork.com/devise-3-1-update/
gem 'devise'
gem 'cancancan'
gem 'role_model'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.7'

# Database gems
# -------------------------------------
# don't change the database gems - causes:
# Please install the <db> adapter: `gem install activerecord-<db>-adapter` (<db> is not part of the bundle. Add it to Gemfile.)
gem 'pg'

# MODELS
# -------------------------------------
gem 'jc-validates_timeliness'

# https://github.com/delynn/userstamp
# no changes in a long time, and we are very dependant on how this works
# this might need to be changed to a fork that is maintained.
# No longer used - incorporated the gem's functionality directly.
#gem 'userstamp', git: 'https://github.com/theepan/userstamp.git'

# https://github.com/brainspec/enumerize
# we need the changes since version 0.8.0. Reassess when there is a new release.
gem 'enumerize', git: 'https://github.com/brainspec/enumerize.git'

gem 'uuidtools'
gem 'acts_as_paranoid', git: 'https://github.com/ActsAsParanoid/acts_as_paranoid.git', branch: :master

# SETTINGS
# -------------------------------------
gem 'settingslogic'
require 'rbconfig'

# TESTING & Documentation
# -------------------------------------
gem 'rspec_api_documentation'
gem 'raddocs'

# MONITORING
# -------------------------------------
gem 'exception_notification'

# MEDIA
# -------------------------------------
# set to a specific commit when releasing to master branch
gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git' #, ref: '07af4484af'
gem 'rack-rewrite'

# ASYNC JOBS
# ------------------------------------
gem 'resque'
gem 'resque-job-stats', git: 'https://github.com/echannel/resque-job-stats.git', ref: '8932c036ae'
gem 'resque-status'
# set to a specific commit when releasing to master branch
gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git' #, ref: '0223c5a1b5'

# Gems restricted by environment and/or platform
# ====================================================

group :production, :staging do
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', platforms: :ruby, require: 'v8'
  gem 'newrelic_rpm'
end

group :development do
  gem 'quiet_assets'
  # capistrano gems
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-rails'
  gem 'capistrano-newrelic'

  gem 'rack-mini-profiler'

  gem 'rails-i18n-debug'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'

  # Run `rails console` in the browser. Read more: https://github.com/rails/web-console
  gem 'web-console'

  # for cleaning up Rails apps
  # gem 'traceroute', require: false
  # gem 'scrap', require: false
  # gem 'rails_best_practices'
  # gem 'rubocop', require: false
  # gem 'rubycritic', require: false
  # gem 'metric_fu', require: false

  # security checkers
  # gem 'codesake-dawn', require: false
  # gem 'brakeman', require: false

  # gem install traceroute scrap brakeman rails_best_practices rubocop rubycritic metric_fu --no-ri --no-rdoc
end

group :development, :test do
  gem 'bullet'
  gem 'rspec-rails'
  gem 'guard'
  gem 'listen'
  gem 'fakeredis', require: 'fakeredis/rspec'
  #gem 'debugger'
end

group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'thin'
  gem 'guard-rspec'
  gem 'guard-yard'
  gem 'rspec'
  gem 'simplecov',  require: false
  gem 'shoulda-matchers'
  gem 'launchy'
  gem 'json_spec'
  gem 'database_cleaner'
  gem 'webmock'
  gem 'coveralls', '~> 0.7.2', require: false
  gem 'codeclimate-test-reporter', require: nil

  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', '~> 0.4.0'
end