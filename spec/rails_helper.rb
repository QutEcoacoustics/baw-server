# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'

# attempting to prevent trivial mistakes
#ENV['RAILS_ENV'] ||= 'test'
if ENV['RAILS_ENV'] != 'test'
  puts \
    <<~MESSAGE
      ***
      Tests must be run in the test envrionment.
      The current envrionment `#{ENV['RAILS_ENV']}` has been changed to `test`.
      See rails_helper.rb to disable this check
      ***
    MESSAGE
  ENV['RAILS_ENV'] = 'test'
end

#abort "You must run tests using 'bundle exec ...'" unless ENV['BUNDLE_BIN_PATH'] || ENV['BUNDLE_GEMFILE']

require 'bundler' # Set up gems listed in the Gemfile.
Bundler.setup(:test)
Bundler.require(:test)

require 'spec_helper'

require 'test-prof'
TestProf.configure do |config|
  # the directory to put artifacts (reports) in ('tmp/test_prof' by default)
  config.output_dir = 'test_prof'

  # use unique filenames for reports (by simply appending current timestamp)
  config.timestamps = true

  # color output
  config.color = true
end

if ENV['CI'] || ENV['COVERAGE']
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

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                     Coveralls::SimpleCov::Formatter,
                                                                     CodeClimate::TestReporter::Formatter
                                                                   ])

  else
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                     SimpleCov::Formatter::HTMLFormatter
                                                                   ])
  end

  # start code coverage
  SimpleCov.start 'rails'
end

require File.expand_path('../config/environment', __dir__)

# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
abort('The Rails environment is running in staging mode!') if Rails.env.staging?
abort('The Rails environment is NOT running in test mode!') unless Rails.env.test?

require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'capybara/rails'
require 'capybara/rspec'
require 'webmock/rspec'
require 'paperclip/matchers'
require 'database_cleaner'
require 'rspec_api_documentation'

require 'helpers/misc_helper'
require 'fixtures/fixtures'

require_relative '../lib/patches/test_response_reuse.rb'

WebMock.disable_net_connect!(allow_localhost: true, allow: 'codeclimate.com')

# gives us the login_as(@user) method when request object is not present
# http://www.schneems.com/post/15948562424/speed-up-capybara-tests-with-devise/
include Warden::Test::Helpers
Warden.test_mode!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # Database cleaner takes care of this instead
  config.use_transactional_fixtures = false
  config.use_transactional_examples = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  # set a random timezone to check for time zone issues
  Zonebie.set_random_timezone
  puts "===> Time zone offset is #{Time.zone.utc_offset}."

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Paperclip::Shoulda::Matchers
  config.include FactoryGirl::Syntax::Methods

  require_relative 'helpers/creation'
  config.include Creation::Example
  config.extend Creation::ExampleGroup

  require_relative 'helpers/citizen_science_creation.rb'
  config.extend CitizenScienceCreation

  require 'enumerize/integrations/rspec'
  extend Enumerize::Integrations::RSpec

  config.before(:suite) do

    # run these rake tasks to ensure the db in is a state that matches the schema.rb
    #bin/rake db:drop RAILS_ENV=test
    #bin/rake db:create RAILS_ENV=test
    #bin/rake db:migrate RAILS_ENV=test
    #bin/rake db:structure:dump RAILS_ENV=test
    #bin/rake db:drop RAILS_ENV=test
    #bin/rake db:create RAILS_ENV=test
    #bin/rake db:structure:load RAILS_ENV=test

    if Rails.env == 'test'
      ActiveRecord::Tasks::DatabaseTasks.drop_current
      ActiveRecord::Tasks::DatabaseTasks.create_current
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current
    end

    # https://github.com/DatabaseCleaner/database_cleaner
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)

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

    # Load seeds for test db
    Rails.application.load_seed
  end

  config.before type: :request do
    # Request specs cannot use a transaction because Capybara runs in a
    # separate thread with a different database connection.
    DatabaseCleaner.strategy = :truncation
  end

  config.after type: :request do
    # Reset so other non-request specs don't have to deal with slow truncation.
    # also, truncation does not keep users created by seeds
    DatabaseCleaner.strategy = :transaction

    # clear paperclip attachments from tmp directory
    FileUtils.rm_rf(Dir["#{Rails.root}/tmp/paperclip/[^.]*"])
  end

  config.before(:each) do |example|
    # ensure any email is cleared
    ActionMailer::Base.deliveries.clear

    # start database cleaner
    DatabaseCleaner.start
    example_description = example.description
    Rails.logger.info "\n\n#{example_description}\n#{'-' * example_description.length}"
  end

  config.after(:each) do
    is_truncating = DatabaseCleaner.connections[0].strategy.class == DatabaseCleaner::ActiveRecord::Truncation

    DatabaseCleaner.clean

    Rails.application.load_seed if is_truncating

    # https://github.com/plataformatec/devise/wiki/How-To:-Test-with-Capybara
    # reset warden after each test
    Warden.test_reset!
  end

  # enable options requests in feature tests
  module ActionDispatch::Integration::RequestHelpers
    def options(path, parameters = nil, headers_or_env = nil)
      process :options, path, parameters, headers_or_env
    end
  end

end

require 'shoulda-matchers'
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

# Customise rspec api documentation
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
