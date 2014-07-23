# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

if ENV['TRAVIS']
  require 'codeclimate-test-reporter'
  CodeClimate::TestReporter.configure do |config|
    config.logger.level = Logger::DEBUG
  end
  CodeClimate::TestReporter.start
end

require 'simplecov'
SimpleCov.start

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

require 'capybara/rails'
require 'capybara/rspec'

require 'database_cleaner'

require 'webmock/rspec'
require 'paperclip/matchers'
WebMock.disable_net_connect!(allow_localhost: true)

# gives us the login_as(@user) method when request object is not present
# http://www.schneems.com/post/15948562424/speed-up-capybara-tests-with-devise/
include Warden::Test::Helpers
Warden.test_mode!

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

  config.include Devise::TestHelpers, type: :controller

  #config.profile_examples = 20
  config.include Paperclip::Shoulda::Matchers

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # DatabaseCLeaner takes care of this instead
  config.use_transactional_fixtures = false
  config.use_transactional_examples = false

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  # mixin core methods
  config.include FactoryGirl::Syntax::Methods
  #config.include Rails.application.routes.url_helpers

  # redirect puts into a text file
  original_stderr = $stderr
  original_stdout = $stdout

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    begin
      DatabaseCleaner.start
      FactoryGirl.lint
    ensure
      DatabaseCleaner.clean
    end
    # Redirect stderr and stdout
    $stderr = File.new(File.join(File.dirname(__FILE__), '..', 'tmp', 'rspec_stderr.txt'), 'w')
    $stdout = File.new(File.join(File.dirname(__FILE__), '..', 'tmp', 'rspec_stdout.txt'), 'w')
  end

  # Request specs cannot use a transaction because Capybara runs in a
  # separate thread with a different database connection.
  config.before type: :request do
    DatabaseCleaner.strategy = :truncation
  end

  # Reset so other non-request specs don't have to deal with slow truncation.
  config.after type: :request do
    # clear paperclip attachments from tmp directory
    DatabaseCleaner.strategy = :transaction
    FileUtils.rm_rf(Dir["#{Rails.root}/tmp/paperclip/[^.]*"])
  end

  config.before(:each) do
    ActionMailer::Base.deliveries.clear
    DatabaseCleaner.start
    example_description = example.description
    Rails::logger.info "\n\n#{example_description}\n#{'-' * (example_description.length)}"

    #Bullet.start_request if Bullet.enable?
  end

  config.after(:each) do
    DatabaseCleaner.clean
    #Bullet.perform_out_of_channel_notifications if Bullet.enable? && Bullet.notification?
    #Bullet.end_request if Bullet.enable?

    # https://github.com/plataformatec/devise/wiki/How-To:-Test-with-Capybara
    # reset warden after each test
    Warden.test_reset!
  end

  config.after(:suite) do
    $stderr = original_stderr
    $stdout = original_stdout
  end

end

RspecApiDocumentation.configure do |config_rspec_api|
  config_rspec_api.format = :json
end
