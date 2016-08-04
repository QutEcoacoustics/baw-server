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

gem 'rails', '~> 4.2.4'
gem 'rack-cors', '~> 0.4.0', require: 'rack/cors'
gem 'responders', '~> 2.2.0'

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
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.2.0'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', '~> 0.12.1', platforms: :ruby, require: 'v8'

# Use jquery as the JavaScript library
gem 'jquery-rails', '~> 4.1.0'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5.0'

gem 'haml', '~> 4.0.6'
gem 'haml-rails', '~> 0.9.0'

gem 'simple_form', '~> 3.2.0'
gem 'paperclip', '~> 5.0.0'
gem 'kramdown', '~> 1.11.0'

# Bootstrap UI
gem 'bootstrap-sass', '~> 3.3.4'
# for sass variables: http://getbootstrap.com/customize/#less-variables
# sprockets-rails gem is included via rails dependency
gem 'font-awesome-sass', '~> 4.6.2'

# for rails 3, 4
gem 'kaminari'
gem 'dotiw','~> 3.1.1'
gem 'recaptcha', '~> 3.3.0',  require: 'recaptcha/rails'

# for proper timezone support
gem 'tzinfo', '~> 1.2.2'
gem 'tzinfo-data', '~> 1.2016'

# USERS & PERMISSIONS
# -------------------------------------
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# http://joanswork.com/devise-3-1-update/
gem 'devise', '~> 4.2.0'
gem 'devise-i18n'
gem 'cancancan', '~> 1.15'
gem 'role_model', '~> 0.8.1'
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.9'
#gem 'rails_admin', '~> 0.7'

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

gem 'enumerize', '~> 1.0'
gem 'uuidtools', '~> 2.1.5'
gem 'acts_as_paranoid', git: 'https://github.com/ActsAsParanoid/acts_as_paranoid.git', branch: :master, ref: 'c2db19554ddaedcac0a2b8d6a0563dea83c972c5'


# for state machines
gem 'aasm'

# SETTINGS
# -------------------------------------
gem 'settingslogic', '~> 2.0.9'
require 'rbconfig'

# MONITORING
# -------------------------------------
gem 'exception_notification', '~> 4.2.0'
gem 'newrelic_rpm', '~> 3.15'

# Documentation & UI
# -------------------------------------
# these gems are required here to serve /doc url
gem 'rspec_api_documentation', '~> 4.8.0'
gem 'raddocs', '~> 1.0.0'

# MEDIA
# -------------------------------------
# set to a specific commit when releasing to master branch
gem 'baw-audio-tools', git: 'https://github.com/QutBioacoustics/baw-audio-tools.git', branch: :master, ref: '354d375d6a'
gem 'rack-rewrite', '~> 1.5.1'

# ASYNC JOBS
# ------------------------------------
gem 'resque', '~> 1.25.2'
gem 'resque-job-stats', git: 'https://github.com/echannel/resque-job-stats.git', branch: :master, ref: '8932c036ae'
gem 'resque-status', '~> 0.5.0'
# set to a specific commit when releasing to master branch
gem 'baw-workers', git: 'https://github.com/QutBioacoustics/baw-workers.git', branch: :master, ref: '18943af4b'


# Gems restricted by environment and/or platform
# ====================================================

# gems that are only required on development machines or for testings
group :development, :test do
  # allow remote debugging
  #gem 'ruby-debug19'
  #gem 'ruby-debug-ide'
  #gem 'debase'
  #gem 'traceroute'

  gem 'quiet_assets'

  gem 'rack-mini-profiler', '~> 0.10.0'
  gem 'i18n-tasks', '~> 0.9.0'
  gem 'bullet', '~> 5.1.0'

  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  #gem 'spring', '~> 1.4.0'

  # Run `rails console` in the browser. Read more: https://github.com/rails/web-console
  #gem 'web-console', '~> 2.1.1'

  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', '~> 0.4.0'

  gem 'thin', '~> 1.7.0'

  gem 'notiffany', '~> 0.1.0'
  gem 'guard', '~> 2.14.0'
  gem 'guard-rspec', '~> 4.7.0'
  gem 'guard-yard', '~> 2.1.4', require: false
  gem 'rubocop', '~> 0.41.0', require: false
  gem 'haml_lint', require: false

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

  gem 'rspec-rails', '~> 3.5.0'
  gem 'factory_girl_rails', '~>  4.7.0'
  gem 'capybara', '~> 2.7.0'

  gem 'rspec', '~> 3.5.0'
  gem 'simplecov', '~> 0.12.0', require: false
  gem 'launchy', '~> 2.4.3'
  gem 'json_spec', '~> 1.1.4'
  gem 'database_cleaner', '~> 1.5.0'

  gem 'coveralls', '~> 0.8.14', require: false
  gem 'codeclimate-test-reporter', '~> 0.6.0', require: nil
end

group :test do
  gem 'webmock', '~> 2.1.0'
  gem 'shoulda-matchers', '< 3.0.0', require: false

  gem 'rspec-mocks', '~>3.5.0'

  # use to mock time in tests - currently not needed
  #gem 'timecop'
end