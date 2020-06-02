# frozen_string_literal: true

source 'https://rubygems.org'

# Available groups:
# development - only for local dev machines
# production - for server deploys (includes staging)
# test - for running tests

# http://ryanbigg.com/2011/01/why-you-should-run-bundle-update/

# Gems required in all environments and all platforms
# ====================================================

# For autoloading Gems. Zeitwerk is the default in Rails 6.
gem 'zeitwerk', require: false

# for proper timezone support
gem 'tzinfo', '~> 1.2.2'
gem 'tzinfo-data'

# for simple caching of functions
gem 'memoist'

# bootsnap helps rails boot quickly
gem 'bootsnap', require: false

group :server do
  # RAILS
  # -------------------------------------
  gem 'rack-cors', '~> 0.4.0', require: 'rack/cors'
  gem 'rails', '~> 4.2.4'
  gem 'responders', '~> 2.3.0'

  # RAILS 3 compatibility gems
  # -------------------------------------
  # gem 'protected_attributes'
  # gem 'rails-observers'
  # gem 'actionpack-page_caching'
  # gem 'actionpack-action_caching'
  # gem 'activerecord-deprecated_finders'
  gem 'activesupport-json_encoder', git: 'https://github.com/rails/activesupport-json_encoder.git', branch: :master, ref: 'd874fd9dbf'

  # UI HELPERS
  # -------------------------------------
  # Use SCSS for stylesheets
  gem 'sass-rails', '~> 5.0.3'
  # Use Uglifier as compressor for JavaScript assets
  gem 'uglifier', '~> 3.0.0'
  # Use CoffeeScript for .js.coffee assets and views
  gem 'coffee-rails', '~> 4.2.0'
  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', '~> 0.12.1', platforms: :ruby, require: 'v8'

  # Use jquery as the JavaScript library
  gem 'jquery-rails', '~> 4.2.0'
  # Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
  #gem 'turbolinks'
  # Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
  gem 'jbuilder', '~> 2.6.0'

  gem 'haml', '~> 4.0.6'
  gem 'haml-rails', '~> 0.9.0'

  gem 'kramdown', '~> 1.13.2'
  gem 'paperclip', '~> 5.2.0'
  gem 'simple_form', '~> 3.3.0'

  # Bootstrap UI
  gem 'bootstrap-sass', '~> 3.3.4'
  # for sass variables: http://getbootstrap.com/customize/#less-variables
  # sprockets-rails gem is included via rails dependency
  gem 'font-awesome-sass', '~> 4.6.2'

  # for rails 3, 4
  gem 'dotiw', '~> 3.1.1'
  gem 'kaminari'
  gem 'recaptcha', '~> 5.1.0', require: 'recaptcha/rails'

  # for tying inflections into I18n
  gem 'i18n-inflector-rails', '~>1.0'

  # USERS & PERMISSIONS
  # -------------------------------------
  # https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
  # http://joanswork.com/devise-3-1-update/
  gem 'cancancan', '~> 1.16'
  gem 'devise', '~> 4.7.0'
  gem 'devise-i18n'
  gem 'role_model', '~> 0.8.1'
  # Use ActiveModel has_secure_password
  gem 'bcrypt', '~> 3.1.9'
  #gem 'rails_admin', '~> 0.7'

  # Database gems
  # -------------------------------------
  # This gem MUST be loaded before any other DB gem
  # It seems the 'pg' loads sqlite itself ... and it loads whichever sqlite lib it was compiled against
  gem 'sqlite3'

  # don't change the database gems - causes:
  # Please install the <db> adapter: `gem install activerecord-<db>-adapter`
  # (<db> is not part of the bundle. Add it to Gemfile.)
  gem 'pg', '~> 0.21'

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
  gem 'enumerize', '~> 2.0'
  gem 'uuidtools', '~> 2.1.5'

  # Note: if other modifications are made to the default_scope
  # there are manually constructed queries that need to be updated to match
  # (search for ':deleted_at' to find the relevant places)
  gem 'acts_as_paranoid', git: 'https://github.com/ActsAsParanoid/acts_as_paranoid.git', branch: :master, ref: 'c2db19554ddaedcac0a2b8d6a0563dea83c972c5'

  # for state machines
  gem 'aasm', '~>4.12.0'

  # MONITORING
  # -------------------------------------
  gem 'exception_notification', '~> 4.2.0'

  # MEDIA?
  # -------------------------------------
  gem 'rack-rewrite', '~> 1.5.1'

  # Other Gems
  # This was needed at some point to boot rails. I think we can remove this dependency later after some gem upgrades
  gem 'concurrent-ruby', '~> 1', require: 'concurrent'

  # Application/webserver
  # We used to use thin for development
  #gem 'thin', '~> 1.7.0'
  # Now we use passenger for all environments. The require: allows for integration
  # with the `rails server` command
  gem 'passenger', require: 'phusion_passenger/rack_handler'
end

group :workers do
  gem 'actionmailer'
  gem 'activesupport'
end

group :workers, :server do
  # SETTINGS
  # -------------------------------------
  gem 'settingslogic', '~> 2.0.9'
  require 'rbconfig'

  # ASYNC JOBS
  # ------------------------------------
  # Resque is hard locked to 1.25.2 because 1.26 has a breaking change with the loggers. When below lands when can bump version.
  # https://github.com/resque/resque/commit/eaaac2acc209456cdd0dd794d2d3714968cf76e4
  gem 'redis', '~> 4.1'
  gem 'resque', '1.25.2'
  gem 'resque-job-stats', git: 'https://github.com/echannel/resque-job-stats.git', branch: :master, ref: '8932c036ae'
  gem 'resque-status', '~> 0.5.0'
  gem 'resque_solo', '~> 0.5.0'
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

  gem 'quiet_assets'

  gem 'bullet', '~> 5.2.0'
  gem 'guard', '~> 2.14.0'
  gem 'guard-yard', '~> 2.1.4', require: false
  gem 'i18n-tasks', '~> 0.9.0'
  gem 'notiffany', '~> 0.1.0'
  gem 'rack-mini-profiler', '~> 0.10.0'
  gem 'rubocop', '~> 0.74.0', require: false

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
end

group :test do
  gem 'capybara', '~> 2.7.0'
  gem 'codeclimate-test-reporter', '~> 0.6.0', require: nil
  gem 'coveralls', '~> 0.8.23', require: false
  gem 'database_cleaner', '~> 1.5.0'
  gem 'factory_girl_rails', '~>  4.7.0'
  gem 'guard-rspec', '~> 4.7.0'
  gem 'json_spec', '~> 1.1.4'
  gem 'rspec', '~> 3.9.0'
  gem 'rspec-mocks', '~>3.9.0'
  gem 'rspec-rails', '~> 3.9.0'
  # for profiling
  gem 'ruby-prof', '>= 0.17.0', require: false
  gem 'shoulda-matchers', '~> 4', require: false
  gem 'simplecov', '~> 0.16', require: false
  # for profiling
  gem 'test-prof', require: false
  gem 'webmock', '~> 3.8.3'
  gem 'zonebie'

  # Documentation & UI
  # -------------------------------------
  # these gems are required here to serve /doc url
  gem 'raddocs', '~> 1.0.0'
  gem 'rspec_api_documentation', '~> 4.8.0'
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', '~> 0.4.0'
end
