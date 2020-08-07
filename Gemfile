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

# standardised way to validate objects
gem 'dry-validation'

# api docs
gem 'rswag-api'
gem 'rswag-ui'

# uri parsing and generation
gem 'addressable'

RAILS_VERSION = '~> 6.0.3'

group :server do
  # RAILS

  # -------------------------------------
  gem 'rack-cors', '~> 1.1.1', require: 'rack/cors'
  gem 'rails', RAILS_VERSION
  gem 'responders', '~> 3.0.1'

  # UI HELPERS
  # -------------------------------------
  # Use SCSS for stylesheets
  gem 'sass-rails'

  # Use jquery as the JavaScript library
  gem 'jquery-rails', '~> 4.2.0'
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

  # for tying inflections into I18n
  gem 'i18n-inflector-rails', '~>1.0', require: false

  # USERS & PERMISSIONS
  # -------------------------------------
  # https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
  # http://joanswork.com/devise-3-1-update/
  gem 'cancancan', '> 3'
  gem 'devise', '~> 4.7.0'
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
  # in particular, we use `cast`
  gem 'arel_extensions'

  # MODELS
  # -------------------------------------
  gem 'jc-validates_timeliness', '~> 3.1.1'

  # https://github.com/delynn/userstamp
  # no changes in a long time, and we are very dependant on how this works
  # this might need to be changed to a fork that is maintained.
  # No longer used - incorporated the gem's functionality directly.
  #gem 'userstamp', git: 'https://github.com/theepan/userstamp.git'

  # enumerize tries to load rspec, even when not in tests for some reason. Do not let it.
  # https://github.com/brainspec/enumerize/blob/master/lib/enumerize.rb
  gem 'enumerize'
  gem 'uuidtools', '~> 2.1.5'

  # Note: if other modifications are made to the default_scope
  # there are manually constructed queries that need to be updated to match
  # (search for ':deleted_at' to find the relevant places)
  gem 'acts_as_paranoid'

  # for state machines
  gem 'aasm', '> 5'

  # MONITORING
  # -------------------------------------
  gem 'exception_notification'

  # MEDIA?
  # -------------------------------------
  gem 'rack-rewrite', '~> 1.5.1'

  # Other Gems
  # This was needed at some point to boot rails. I think we can remove this dependency later after some gem upgrades
  gem 'concurrent-ruby', '~> 1', require: 'concurrent'

  # Application/webserver
  # We used to use thin for development
  gem 'thin', group: [:development, :test]
  # Now we use passenger for all environments. The require: allows for integration
  # with the `rails server` command
  gem 'passenger', require: 'phusion_passenger/rack_handler'
end

group :workers do
  gem 'actionmailer', RAILS_VERSION
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
  gem 'resque'
  gem 'resque-job-stats'
  # source copied into repo, see lib/gems/resque-status
  # bypass 'installing' local gems while building the container.
  # because full web app has not yet been copied to the container.
  load_local = !ENV.key?('BAW_SKIP_LOCAL_GEMS')
  if load_local
    install_if -> { load_local } do
      gem 'resque-status', path: 'lib/gems/resque-status'
    end
  end
  gem 'resque_solo'
end

# gems that are only required on development machines or for testings
group :development do
  # allow debugging
  gem 'debase', '>= 0.2.5.beta1'
  gem 'readapt'
  gem 'ruby-debug-ide', '>= 0.7.2'
  #gem 'traceroute'

  # a ruby language server
  gem 'solargraph'

  gem 'bullet'
  gem 'i18n-tasks', '~> 0.9.0'
  gem 'notiffany', '~> 0.1.0'
  gem 'rack-mini-profiler', '>= 2.0.2'

  # linting and formatting
  gem 'rubocop', require: false

  # generating changelogs
  gem 'github_changelog_generator'
end

group :test do
  gem 'coveralls', '>= 0.8.23', require: false
  gem 'database_cleaner-active_record'
  gem 'database_cleaner-redis'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'json_spec', '~> 1.1.4'
  gem 'rspec'
  gem 'rspec-collection_matchers'
  gem 'rspec-mocks'
  # for profiling
  gem 'ruby-prof', '>= 0.17.0', require: false
  gem 'shoulda-matchers', '~> 4', require: false
  gem 'simplecov', require: false
  # for profiling
  gem 'test-prof', require: false
  gem 'webmock'
  gem 'zonebie'

  # api docs
  gem 'rspec-rails'
  gem 'rswag-specs'

  # old docs (deprecated)
  gem 'rspec_api_documentation', '~> 4.8.0'
end
