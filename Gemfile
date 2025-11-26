# frozen_string_literal: true

source 'https://rubygems.org'

# Available groups:
# development - only for local dev machines
# production - for server deploys (includes staging)
# test - for running tests

# http://ryanbigg.com/2011/01/why-you-should-run-bundle-update/

# Gems required in all environments and all platforms
# ====================================================

# for proper timezone support
gem 'tzinfo' # active support pins the version of tzinfo, no point in setting it here
gem 'tzinfo-data'

# Rails standard library
# Used anywhere we need CSV: audio event download and import, and our API
gem 'csv'

# for simple caching of functions
gem 'memoist'

# bootsnap helps rails boot quickly
gem 'bootsnap', require: false

# logging
gem 'amazing_print'
gem 'rails_semantic_logger', '>= 4.11.0'
gem 'semantic_logger'

# standardised way to validate objects
gem 'dry-monads'
gem 'dry-struct'
gem 'dry-transformer'
gem 'dry-validation'

# Async/promises/futures
gem 'concurrent-ruby', '~> 1', require: 'concurrent'
gem 'concurrent-ruby-edge', require: 'concurrent-edge'

# next gen http client used by sftpgo-client, Upload service API
gem 'faraday', '>2.0.1'
gem 'faraday-encoding'
gem 'faraday-multipart'
gem 'faraday-parse_dates'
gem 'faraday-retry'

# used for connecting to PBS clusters via the batch analysis service
gem 'bcrypt_pbkdf'
gem 'ed25519'
gem 'net-scp', '>= 4.0.0'
gem 'net-ssh', '>= 7.3.0.rc1'
gem 'openssl'

# currently only used for testing jwts sent by sftpgo
# 2022-11: now also used for analysis job http updates
gem 'jwt'

# api docs
gem 'rswag-api'
gem 'rswag-ui'

# uri parsing and generation
gem 'addressable'

gem 'descriptive-statistics'

# for sorting hashes by keys
gem 'deep_sort'

RAILS_VERSION = '~> 8.0.2'

# RAILS

# -------------------------------------
gem 'rack-cors', '~> 1.1.1', require: 'rack/cors'
gem 'rails', RAILS_VERSION

# bumping to latest RC because it has pre-compiled native binaries
gem 'nokogiri'

# cms
# AT 2025: ComfortableMexicanSofa is deprecated.
# It's causing issues so we forked it. Mainly gem updates. See the README.md in our fork of comfortable-mexican-sofa.
#  Note: the successor is ComfortableMediaSurfer, but doesn't work for us because it adds new features, particularly
#  around asset management. We don't have a node environment or build pipeline, so it is a pain to use.
gem 'comfortable_mexican_sofa', git: 'https://github.com/QutEcoacoustics/comfortable-mexican-sofa.git', ref: 'master'

# UI HELPERS
# -------------------------------------
# Use SCSS for stylesheets
gem 'sass-rails'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.3'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
#gem 'jbuilder' # deprecate this maybe? let's see what fails!

gem 'haml', '~> 5.1.2'
gem 'haml-rails', '~> 2'

gem 'kramdown', '~> 2'
gem 'kramdown-parser-gfm'
# AT 2025: Paperclip has long been deprecated in favour of ActiveStorage.
# We don't have the bandwidth to migrate to ActiveStorage yet. The repo is unmaintained and causes issues.
# We've switched to a fork that was recommended by the Paperclip maintainers.
# https://github.com/kreeti/kt-paperclip
gem 'kt-paperclip', '> 7.0.0'
gem 'simple_form'

# Bootstrap UI
gem 'bootstrap-sass', '~> 3.4.1'
# for sass variables: http://getbootstrap.com/customize/#less-variables
# sprockets-rails gem is included via rails dependency
gem 'font-awesome-sass', '~> 4.6.2'

# for rails 3, 4
gem 'dotiw'
# Easy paging, adds scopes to ActiveRecord objects  like .page()
gem 'kaminari'
gem 'recaptcha', require: 'recaptcha/rails'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# http://joanswork.com/devise-3-1-update/
gem 'cancancan', '> 3'
gem 'devise', '~> 4.9.4'
gem 'devise-i18n'
gem 'role_model', '~> 0.8.1'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.9'

# Database gems
# -------------------------------------
# This gem MUST be loaded before any other DB gem
# It seems the 'pg' loads sqlite itself ... and it loads whichever sqlite lib it was compiled against
gem 'sqlite3'

# take care when changing the database gems
gem 'pg'

# extensions to arel https://github.com/Faveod/arel-extensions
# in particular, we use `cast`, and `coalesce`
gem 'arel_extensions', '>= 2.1.0'

# MODELS
# -------------------------------------
gem 'activerecord_json_validator'
gem 'validates_timeliness', '~> 8.0.0.beta1'
gem 'validate_url', git: 'https://github.com/perfectline/validates_url.git',
  ref: '81ec1516423af0b4fdc7cabbcda0089e434f2703'

# https://github.com/delynn/userstamp
# no changes in a long time, and we are very dependant on how this works
# this might need to be changed to a fork that is maintained.
# No longer used - incorporated the gem's functionality directly.
#gem 'userstamp', git: 'https://github.com/theepan/userstamp.git'

# enumerize tries to load rspec, even when not in tests for some reason. Do not let it.
# https://github.com/brainspec/enumerize/blob/master/lib/enumerize.rb
gem 'enumerize'
gem 'uuidtools', '~> 2.1.5'

# validations for active_storage files
gem 'active_storage_validations'

# for state machines
gem 'aasm', '> 5'
gem 'after_commit_everywhere'

# MONITORING
# -------------------------------------
gem 'exception_notification'

# MEDIA?
# -------------------------------------
gem 'rack-rewrite', '~> 1.5.1'

# Application/webserver
# Now we use passenger for all environments. The require: allows for integration
# with the `rails server` command
gem 'passenger', require: 'phusion_passenger/rack_handler'
# https://github.com/phusion/passenger/issues/2559
gem 'rack', '>= 3.0.0'
gem 'rackup', '>= 2.0.0'

# For autoloading Gems. Zeitwerk is the default in Rails 6.
gem 'zeitwerk', '>= 2.3', require: false

# SETTINGS
# -------------------------------------
gem 'config'

# ASYNC JOBS
# ------------------------------------
gem 'redis', '~> 4.1'
gem 'resque', '~> 2.5'
gem 'resque-job-stats'
gem 'resque-scheduler'

# Active storage analyzers
gem 'image_processing'
gem 'mini_magick', '>= 4.9.5'

# analysis results
# -------------------------------------
gem 'rubyzip', '>= 3.0.0.alpha'

# gems that are only required on development machines or for testings
group :development do
  # allow debugging
  gem 'debug'

  # a ruby language server
  gem 'ruby-lsp'
  # solargraph is so slow, we're moving away from it
  gem 'solargraph', '>= 0.56.1'
  gem 'solargraph-rails', '>= 0.3.1'

  # official ruby typing support
  gem 'typeprof'

  # needed by bundler/soalrgraph for language server?
  gem 'actionview', RAILS_VERSION

  gem 'i18n-tasks', '~> 1.0.15'
  gem 'notiffany', '~> 0.1.0'
  gem 'rack-mini-profiler', '>= 2.0.2'

  # generating changelogs
  gem 'github_changelog_generator'

  # documents models
  # originally 'annotate' but it is not maintained anymore
  gem 'annotaterb'
end

group :development, :test do
  # restart workers when their code changes
  gem 'rerun'

  # linting and formatting
  gem 'rubocop', require: false
  gem 'rubocop-factory_bot', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false

  # factories for data objects
  # allows factory generators to be used when in devlepment group as well as test
  gem 'factory_bot_rails'

  # rspec helpers for rails
  # allows factory generators to be used when in development group as well as test
  gem 'rspec-rails'

  # we're using falcon and these async primitives in web_server_helper for tests
  gem 'async', git: 'https://github.com/socketry/async'
  gem 'async-http', git: 'https://github.com/socketry/async-http'
  gem 'falcon', git: 'https://github.com/socketry/falcon'
end

group :test do
  gem 'coveralls', '>= 0.8.23', require: false
  gem 'database_cleaner-active_record'
  gem 'database_cleaner-redis'

  gem 'faker'
  gem 'json_spec', '~> 1.1.4'
  gem 'rspec'
  gem 'rspec-benchmark'
  gem 'rspec-collection_matchers'
  gem 'rspec-its'
  gem 'rspec-mocks'
  # for use in rspec HTML reports
  gem 'coderay'
  gem 'timecop'

  # better diffs
  gem 'super_diff'

  # allow for temporary tables in tests for anonymous models
  gem 'temping'

  # for profiling
  gem 'ruby-prof', '>= 0.17.0', require: false
  gem 'shoulda-matchers', '~> 6', require: false
  gem 'simplecov', require: false
  # for profiling
  gem 'test-prof', require: false
  gem 'webmock'
  gem 'zonebie'

  # api docs
  gem 'rswag-specs'

  # old docs (deprecated)
  # https://github.com/zipmark/rspec_api_documentation/issues/548
  gem 'rspec_api_documentation', github: 'SchoolKeep/rspec_api_documentation'

  # test for slow n+1 queries
  gem 'bullet'
end
