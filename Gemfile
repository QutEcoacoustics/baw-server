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

# for simple caching of functions
gem 'memoist'

# bootsnap helps rails boot quickly
gem 'bootsnap', require: false

# logging
gem 'amazing_print'
gem 'rails_semantic_logger', '>= 4.10.0'
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
gem 'faraday-parse_dates'
gem 'faraday-retry'

# used for connecting to PBS clusters via the batch analysis service
gem 'bcrypt_pbkdf'
gem 'ed25519'
gem 'net-scp', '>= 4.0.0.rc1'
gem 'net-ssh'

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

# DO NOT change rails version without also changing composite_primary_keys version
# https://github.com/composite-primary-keys/composite_primary_keys
RAILS_VERSION = '~> 7.0.1'
COMPOSITE_PRIMARY_KEYS_VERSION = '~> 14'

group :server do
  # RAILS

  # -------------------------------------
  gem 'rack-cors', '~> 1.1.1', require: 'rack/cors'
  gem 'rails', RAILS_VERSION

  # deal with chrome and same site cookies
  gem 'rails_same_site_cookie'

  # bumping to latest RC because it has pre-compiled native binaries
  gem 'nokogiri', '~> 1.13.3'

  # cms
  gem 'comfortable_mexican_sofa', '~> 2.0.0'

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
  gem 'haml-rails', '~> 2.0.1'

  gem 'kramdown', '~> 2.3.0'
  gem 'kramdown-parser-gfm'
  gem 'paperclip', '> 6.0.0'
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
  gem 'devise', '~> 4.8.1'
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

  # as the name says
  gem 'composite_primary_keys', COMPOSITE_PRIMARY_KEYS_VERSION

  # allows for adding common table expressions to queries
  gem 'activerecord-cte'

  # MODELS
  # -------------------------------------
  gem 'validates_timeliness', '~> 6.0.0.alpha1'

  # https://github.com/delynn/userstamp
  # no changes in a long time, and we are very dependant on how this works
  # this might need to be changed to a fork that is maintained.
  # No longer used - incorporated the gem's functionality directly.
  #gem 'userstamp', git: 'https://github.com/theepan/userstamp.git'

  # enumerize tries to load rspec, even when not in tests for some reason. Do not let it.
  # https://github.com/brainspec/enumerize/blob/master/lib/enumerize.rb
  gem 'enumerize'
  gem 'uuidtools', '~> 2.1.5'

  # NOTE: if other modifications are made to the default_scope
  # there are manually constructed queries that need to be updated to match
  # (search for ':deleted_at' to find the relevant places)
  gem 'acts_as_paranoid'

  # validations for active_storage files
  gem 'active_storage_validations'

  # for state machines
  gem 'aasm', '> 5'

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
end

group :workers do
  gem 'actionmailer', RAILS_VERSION
  gem 'activejob', RAILS_VERSION
  #gem 'activerecord', RAILS_VERSION
  gem 'activestorage', RAILS_VERSION
  gem 'activesupport', RAILS_VERSION
end

group :workers, :server do
  # For autoloading Gems. Zeitwerk is the default in Rails 6.
  gem 'zeitwerk', '>= 2.3', require: false

  # SETTINGS
  # -------------------------------------
  gem 'config'

  # ASYNC JOBS
  # ------------------------------------
  gem 'redis', '~> 4.1'
  gem 'resque', git: 'https://github.com/resque/resque/', ref: '38c21eb942f3c07cc06fb2c1bc6d9982e2ff075d'
  gem 'resque-job-stats'
  gem 'resque-scheduler'

  # Active storage analyzers
  gem 'image_processing'
  gem 'mini_magick', '>= 4.9.5'
end

# gems that are only required on development machines or for testings
group :development do
  # allow debugging
  #gem 'debase', '>= 0.2.5.beta2'
  gem 'debug', '>= 1.0.0'
  gem 'readapt'
  #gem 'ruby-debug-ide', '>= 0.7.2'
  #gem 'traceroute'

  # a ruby language server
  gem 'solargraph', '>= 0.45.0'
  gem 'solargraph-rails', '>= 0.3.1'

  # official ruby typing support
  gem 'typeprof'

  # needed by bundler/soalrgraph for language server?
  gem 'actionview', RAILS_VERSION

  gem 'i18n-tasks', '~> 0.9.31'
  gem 'notiffany', '~> 0.1.0'
  gem 'rack-mini-profiler', '>= 2.0.2'

  # linting and formatting
  gem 'rubocop', require: false

  # generating changelogs
  gem 'github_changelog_generator'

  # documents models
  gem 'annotate'
end

group :development, :test do
  # restart workers when their code changes
  gem 'rerun'

  # linting
  gem 'rubocop-rspec', require: false

  # factories for data objects
  # allows factory generators to be used when in devlepment group as well as test
  gem 'factory_bot_rails'

  # rspec helpers for rails
  # allows factory generators to be used when in development group as well as test
  gem 'rspec-rails', '~> 6.0.0.rc1'

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
  # 0.8.0 causes ifinite hangs during some specs (spec/requests/media/edge_cases_spec.rb)
  gem 'super_diff'

  # for profiling
  gem 'ruby-prof', '>= 0.17.0', require: false
  gem 'shoulda-matchers', '~> 4', require: false
  gem 'simplecov', require: false
  # for profiling
  gem 'test-prof', require: false
  gem 'webmock'
  gem 'zonebie'

  # api docs
  gem 'rswag-specs'

  # old docs (deprecated)
  gem 'rspec_api_documentation', '~> 4.8.0'

  # test for slow n+1 queries
  gem 'bullet'
end
