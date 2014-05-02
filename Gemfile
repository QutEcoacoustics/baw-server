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
# using rails 3.2.x because upgrading to rails 4 involves lots of breaking changes
gem 'rails', '~> 3.2'
gem 'rack-cors', require: 'rack/cors'

# UI HELPERS
# -------------------------------------
gem 'haml'
gem 'haml-rails', '< 0.5' # from 0.5 activesupport > 3.2 is required
gem 'jquery-rails'
gem 'simple_form' #https://github.com/plataformatec/simple_form
gem 'paperclip'
gem 'breadcrumbs_on_rails'
# kept below version 2 due to huge breaking changes
gem 'gmaps4rails', '< 2'
gem 'twitter-bootstrap-rails', git: 'https://github.com/seyhunak/twitter-bootstrap-rails.git' # https://github.com/seyhunak/twitter-bootstrap-rails
gem 'bootstrap-timepicker-rails'
gem 'bootstrap-datepicker-rails'
# for rails 3, 4
gem 'will_paginate', '~> 3.0'
gem 'dotiw'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# using devise 3.0.x because 3.1 introduces breaking changes
gem 'devise', '< 3.1'
gem 'cancan'
gem 'role_model'
# gem 'userstamp' # https://github.com/delynn/userstamp

# Database gems
# -------------------------------------
# don't change the database gems - causes:
# Please install the <db> adapter: `gem install activerecord-<db>-adapter` (<db> is not part of the bundle. Add it to Gemfile.)
gem 'pg'

# MODELS
# -------------------------------------
gem 'validates_timeliness'
gem 'userstamp', git: 'https://github.com/theepan/userstamp.git' # https://github.com/delynn/userstamp
gem 'enumerize', git: 'https://github.com/brainspec/enumerize.git' #https://github.com/brainspec/enumerize
gem 'uuidtools'
gem 'acts_as_paranoid'

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
gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git'
gem 'rack-rewrite'

# ASYNC JOBS
# ------------------------------------
gem 'resque'
gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git'

# Gems restricted by environment and/or platform
# ====================================================

group :assets do
  # Gems used only for assets and not required
  # in production environments by default.
  # keep consistent with Rails version
  gem 'coffee-rails', '~> 3.2'
  gem 'sass-rails'
  # must be this version or greater to run successfully
  gem 'uglifier', '>= 1.0.3'
end

group :production, :staging do
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', '>= 0.11.3', platforms: :ruby, require: 'v8'
  gem 'newrelic_rpm'
end

group :development do
  gem 'quiet_assets', '>= 1.0.2'
  # capistrano gems
  gem 'capistrano', '~> 3.2'
  gem 'capistrano-bundler'
  gem 'capistrano-rvm'
  gem 'capistrano-rails'
  gem 'capistrano-newrelic'

  gem 'rack-mini-profiler'
  #gem 'scrap'
  gem 'rails-i18n-debug'
end

group :development, :test do
  gem 'bullet'
  gem 'rspec-rails', '>= 2.0.1'
  gem 'guard', '~> 1.8'
  gem 'listen', '~> 1'
  gem 'wdm', '>= 0.1.0', platforms: [:mswin, :mingw]
end

group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  #gem 'capybara-webkit' # needed to test javascript UI with capybara, but couldn't get it to work
  gem 'thin'
  gem 'guard-rspec'
  # fixed version due to unresolved bug in higher versions
  gem 'simplecov', '0.7.1', require: false
  gem 'shoulda-matchers'
  gem 'launchy'
  gem 'json_spec'
  gem 'database_cleaner', '~> 1'
  #gem 'bullet'
  gem 'webmock'
  gem 'coveralls', require: false
end

group :production, :staging, :development do
  gem 'ruby-progressbar'
end
