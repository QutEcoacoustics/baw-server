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
gem 'rails', '~> 3.2.18'
gem 'rack-cors', '~> 0.2.9', require: 'rack/cors'

# UI HELPERS
# -------------------------------------
gem 'haml', '~> 4.0.5'
gem 'haml-rails', '~> 0.4' # from 0.5 activesupport > 3.2 is required
gem 'jquery-rails', '~> 3.1.0'
gem 'simple_form', '~> 2.1.1' #https://github.com/plataformatec/simple_form
gem 'paperclip', '~> 4.1.1'
gem 'breadcrumbs_on_rails', '~> 2.3.0'
# kept below version 2 due to huge breaking changes
gem 'gmaps4rails', '~> 1.5.6'
gem 'twitter-bootstrap-rails', git: 'https://github.com/seyhunak/twitter-bootstrap-rails.git' # https://github.com/seyhunak/twitter-bootstrap-rails
gem 'bootstrap-timepicker-rails', '~> 0.1.3'
gem 'bootstrap-datepicker-rails', '~> 1.3.0.2'
# for rails 3, 4
gem 'will_paginate', '~> 3.0'
gem 'dotiw', '~> 1.1.1'
gem 'recaptcha', '~> 0.3.6', require: 'recaptcha/rails'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# using devise 3.0.x because 3.1 introduces breaking changes
gem 'devise', '< 3.1'
gem 'cancan', '~> 1.6.10'
gem 'role_model', '~> 0.8.1'
# gem 'userstamp' # https://github.com/delynn/userstamp

# Database gems
# -------------------------------------
# don't change the database gems - causes:
# Please install the <db> adapter: `gem install activerecord-<db>-adapter` (<db> is not part of the bundle. Add it to Gemfile.)
gem 'pg', '~> 0.17.1'

# MODELS
# -------------------------------------
gem 'validates_timeliness', '~> 3.0.14'
gem 'userstamp', git: 'https://github.com/theepan/userstamp.git' # https://github.com/delynn/userstamp
gem 'enumerize', git: 'https://github.com/brainspec/enumerize.git' #https://github.com/brainspec/enumerize
gem 'uuidtools', '~> 2.1.4'
gem 'acts_as_paranoid', '~> 0.4.2'

# SETTINGS
# -------------------------------------
gem 'settingslogic', '~> 2.0.9'
require 'rbconfig'

# TESTING & Documentation
# -------------------------------------
gem 'rspec_api_documentation', '~> 3.0.0'
gem 'raddocs', '~> 0.4.0'

# MONITORING
# -------------------------------------
gem 'exception_notification', '~> 4.0.1'

# MEDIA
# -------------------------------------
gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git'
gem 'rack-rewrite', '~> 1.5.0'

# ASYNC JOBS
# ------------------------------------
gem 'resque', '~> 1.25.2'
gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git'

# Gems restricted by environment and/or platform
# ====================================================

group :assets do
  # Gems used only for assets and not required
  # in production environments by default.
  # keep consistent with Rails version
  gem 'coffee-rails', '~> 3.2'
  gem 'sass-rails', '~> 3.2.6'
  # must be '>= 1.0.3' or greater to run successfully
  gem 'uglifier', '~> 2.5.0'
end

group :production, :staging do
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', '>= 0.11.3', platforms: :ruby, require: 'v8'
  gem 'newrelic_rpm', '~> 3.8.0'
end

group :development do
  gem 'quiet_assets', '~> 1.0.2'
  # capistrano gems
  gem 'capistrano', '~> 3.2.1'
  gem 'capistrano-bundler', '~> 1.1.2'
  gem 'capistrano-rvm', '~> 0.1.1'
  gem 'capistrano-rails', '~> 1.1.1'
  gem 'capistrano-newrelic', '~> 0.0.8'

  gem 'rack-mini-profiler', '~> 0.9.1'
  #gem 'scrap'
  gem 'rails-i18n-debug', '~> 1.0.1'
end

group :development, :test do
  gem 'bullet', '~> 4.9.0'
  gem 'rspec-rails', '~> 2.14.2'
  gem 'guard', '~> 1.8.3'
  gem 'listen', '~> 1.3.1'
  gem 'wdm', '>= 0.1.0', platforms: [:mswin, :mingw]
end

group :test do
  gem 'factory_girl_rails', '~> 4.4.1'
  gem 'capybara', '~> 2.2.1'
  gem 'thin', '~> 1.6.2'
  gem 'guard-rspec', '~> 3.1.0'
  # fixed version due to unresolved bug in higher versions
  gem 'simplecov', '~> 0.7.1', require: false
  gem 'shoulda-matchers', '~> 2.6.1'
  gem 'launchy', '~> 2.4.2'
  gem 'json_spec', '~> 1.1.1'
  gem 'database_cleaner', '~> 1.2'
  gem 'webmock', '~> 1.18.0'
  gem 'coveralls', '~> 0.7.0', require: false
end