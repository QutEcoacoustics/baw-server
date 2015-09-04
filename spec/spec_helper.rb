# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'

require 'simplecov'

if ENV['TRAVIS']
  require 'codeclimate-test-reporter'
  require 'coveralls'

  # code climate
   CodeClimate::TestReporter.configure do |config|
     config.logger.level = Logger::WARN
   end
   CodeClimate::TestReporter.start

  # coveralls
  Coveralls.wear!('rails')

  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      Coveralls::SimpleCov::Formatter,
      CodeClimate::TestReporter::Formatter
  ]

else
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter
  ]
end

# start code coverage
SimpleCov.start 'rails'

require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'rake'

require 'capybara/rails'
require 'capybara/rspec'

require 'database_cleaner'
require 'helpers/misc_helper'

require 'webmock/rspec'
require 'paperclip/matchers'

# require all custom rspec matchers
Dir[File.expand_path(File.join(File.dirname(__FILE__),'support','**','*.rb'))].each {|f| require f}

WebMock.disable_net_connect!(allow_localhost: true, allow: 'codeclimate.com')

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

  # ensure gem paths are not shown in the backtrace
  config.backtrace_exclusion_patterns = [/\/\.rvm\/gems\//]

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  # config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # stop on first failure
  #config.fail_fast = true

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

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

  Zonebie.set_random_timezone
  puts "===> Time zone offset is #{Time.zone.utc_offset}."

  # mixin core methods
  config.include FactoryGirl::Syntax::Methods
  #config.include Rails.application.routes.url_helpers

  # redirect puts into a text file
  original_stderr = $stderr
  original_stdout = $stdout

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)

    # run these rake tasks to ensure the db in is a state that matches the schema.rb
    #bin/rake db:drop RAILS_ENV=test
    #bin/rake db:create RAILS_ENV=test
    #bin/rake db:migrate RAILS_ENV=test
    #bin/rake db:structure:dump RAILS_ENV=test
    #bin/rake db:structure:load RAILS_ENV=test

    begin
      DatabaseCleaner.start
      puts '===> Database cleaner: start.'
      #puts '===> FactoryGirl lint: started.'
      #FactoryGirl.lint
      #puts '===> FactoryGirl lint: completed.'
    ensure
      DatabaseCleaner.clean
      puts '===> Database cleaner: cleaned.'
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

  config.before(:each) do |example|
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

  # http://www.relishapp.com/rspec/rspec-rails/v/3-1/docs/upgrade
  ActiveRecord::Migration.maintain_test_schema!

  # enable options requests in feature tests
  module ActionDispatch::Integration::RequestHelpers
    def options(path, parameters = nil, headers_or_env = nil)
      process :options, path, parameters, headers_or_env
    end
  end

end

ENV['DOC_FORMAT'] ||= 'json'

RspecApiDocumentation.configure do |config_rspec_api|
  config_rspec_api.format = ENV['DOC_FORMAT']

  # patch to enable options request
  module RspecApiDocumentation
    class ClientBase
      def http_options_verb(*args)
        process :options, *args
      end
    end
  end

  RspecApiDocumentation::DSL::Resource::ClassMethods.define_action :http_options_verb

end
