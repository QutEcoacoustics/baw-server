# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'

require 'simplecov'
SimpleCov.start

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'capybara/rspec'
require 'rspec/autorun'
require 'database_cleaner'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # ## Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  # mixin core methods
  config.include FactoryGirl::Syntax::Methods
  #config.include Rails.application.routes.url_helpers

  # clear paperclip attachments from tmp directory
  RSpec.configure do |config|
    config.after {
      FileUtils.rm_rf(Dir["#{Rails.root}/tmp/paperclip/[^.]*"])
    }
  end

  RspecApiDocumentation.configure do |config|
    config.format = :json
  end

  config.before(:suite) do

    current_adapter = ActiveRecord::Base.configurations[Rails.env]['adapter']

    ##for mysql
    ##https://github.com/bmabey/database_cleaner
    ##http://stackoverflow.com/a/5964483
    ##http://stackoverflow.com/a/9248602
    ##I found the SQLite exception solution was to remove the clean_with(:truncation) and
    ##change the strategy entirely to DatabaseCleaner.strategy = :truncation

    if current_adapter == 'mysql2'
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.clean_with(:truncation)
    end

    ## for sqlite3
    if current_adapter == 'sqlite3'
      DatabaseCleaner.strategy = :truncation
    end

    ## http://stackoverflow.com/questions/5568367/rails-migration-and-column-change
    ## add this Around line 535 (in version 3.2.9) of
    ## $GEM_HOME/gems/activerecord-3.2.9/lib/active_record/connection_adapters/sqlite_adapter.rb
    ## indexes can't be more than 64 chars long
    ##opts[:name] = opts[:name][0..63]
    ## !! This is now patched in config/initializers/patches.rb

  end

  config.before(:each) do
    #puts 'Database cleaner start...'
    DatabaseCleaner.start
    #empty_file = File.join(Rails.root, 'db', 'test-empty.sqlite3')
    #using_file = File.join(Rails.root, 'db', 'test.sqlite3')
    #File.delete using_file if File.exists? using_file
    #File.copy empty_file, using_file
    #puts '...database cleaner start complete.'
  end

  config.after(:each) do
    #puts 'Begining database clean...'
    DatabaseCleaner.clean
    #puts '...database clean done.'
  end

end
