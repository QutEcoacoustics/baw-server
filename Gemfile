source 'https://rubygems.org'

gem 'rails', '~> 3.2'

# http://ryanbigg.com/2011/01/why-you-should-run-bundle-update/
########################  DATABASES  ########################
gem 'pg' # http://bundler.io/v1.3/man/gemfile.5.html
gem 'sqlite3', platforms: [:mswin, :mingw]
# don't change the database gems
########################  ASSETS  ########################

group :production, :staging do
  gem 'newrelic_rpm'
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails', '~> 3.2'
  #gem 'less-rails',   '>= 2.2.6'
  gem 'sass-rails'

  gem 'uglifier', '>= 1.0.3'
end

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', '>= 0.11.3', platforms: :ruby, require: 'v8', group: [:production, :staging]
gem 'pg', group: [:production, :staging]
# don't change the database gems - causes:
# Please install the <db> adapter: `gem install activerecord-<db>-adapter` (<db> is not part of the bundle. Add it to Gemfile.)
########################  DEVELOPMENT  ########################
group :development do
  gem 'quiet_assets', '>= 1.0.2'
  gem 'bullet'
  # capistrano gems
  gem 'capistrano', '~> 2', require: false
  gem 'rvm-capistrano'

  gem 'rack-mini-profiler'
  #gem 'scrap'
end

########################  TESTING  ########################
gem 'rspec-rails', '>= 2.0.1', group: [:development, :test]
group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  #gem 'capybara-webkit' # needed to test javascript UI with capybara, but couldn't get it to work
  gem 'thin'
  gem 'guard-rspec'
  gem 'simplecov', '0.7.1', require: false
  gem 'faker'
  gem 'shoulda-matchers'
  gem 'launchy'
  gem 'json_spec'
  gem 'database_cleaner', '~> 1'
  #gem 'bullet'
end

########################  TESTING & Documentation ########################

gem 'rspec_api_documentation'
gem 'raddocs'

########################  USERS & PERMISSIONS ########################
# https://github.com/plataformatec/devise/blob/master/CHANGELOG.md
# using devise 3.0.x because 3.1 introduces breaking changes
gem 'devise', '< 3.1'
gem 'cancan'
gem 'role_model'
# gem 'userstamp' # https://github.com/delynn/userstamp

########################  UI HELPERS ########################
gem 'haml', '>= 3.0.0'
gem 'haml-rails'
gem 'jquery-rails'
gem 'simple_form' #https://github.com/plataformatec/simple_form
gem 'paperclip'
gem 'breadcrumbs_on_rails'
gem 'gmaps4rails', '< 2'
gem 'twitter-bootstrap-rails', git: 'https://github.com/seyhunak/twitter-bootstrap-rails.git' # https://github.com/seyhunak/twitter-bootstrap-rails
gem 'bootstrap-timepicker-rails'
gem 'bootstrap-datepicker-rails'
# gem 'select2-rails', '>=3.3.2'
gem 'will_paginate', '~> 3.0.5'


########################  MISC ########################
gem 'enumerize', git: 'https://github.com/brainspec/enumerize.git' #https://github.com/brainspec/enumerize
gem 'uuidtools'
gem 'validates_timeliness'
gem 'userstamp', git: 'https://github.com/theepan/userstamp.git' # https://github.com/delynn/userstamp
gem 'settingslogic'
gem 'acts_as_paranoid'
gem 'trollop'
#gem 'daemons-rails'
gem 'exception_notification'
gem 'bindata'

gem 'guard', '~> 1.8'
gem 'listen', '~> 1'

require 'rbconfig'
gem 'wdm', '>= 0.1.0', platforms: [:mswin, :mingw]

gem 'rack-cors', require: 'rack/cors'

gem 'ruby-progressbar', group: [:production, :staging, :development]