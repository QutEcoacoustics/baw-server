# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'

# attempting to prevent trivial mistakes
#ENV['RAILS_ENV'] ||= 'test'
if ENV.fetch('RAILS_ENV', nil) != 'test'
  puts \
    <<~MESSAGE
      ***
      Tests must be run in the test environment.
      The current environment `#{ENV.fetch('RAILS_ENV', nil)}` has been changed to `test`.
      See #{__FILE__} to disable this check
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

if ENV.fetch('CI', nil) || ENV.fetch('COVERAGE', nil)
  require 'simplecov'

  if ENV['GITHUB_WORKFLOW']
    require 'codeclimate-test-reporter'
    require 'coveralls'

    # code climate
    CodeClimate::TestReporter.configure do |config|
      config.logger.level = Logger::WARN
    end
    CodeClimate::TestReporter.start

    # coveralls
    Coveralls.wear!('rails')

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
      [Coveralls::SimpleCov::Formatter, CodeClimate::TestReporter::Formatter]
    )

  else
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new(
      [SimpleCov::Formatter::HTMLFormatter]
    )
  end

  # start code coverage
  SimpleCov.start 'rails'
end

# If app loading fails, rspec just continues trying to load the next file
# which will generate hundreds of misleading errors which mask the true error.
# Instead, fail fast if the rails app fails to load!
begin
  require "#{__dir__}/../config/environment"
rescue StandardError => e
  puts e.full_message(highlight: true, order: :top)
  exit 1
end

# Prevent accidental non-tests database access!
Kernel.abort('The Rails environment is running in production mode!') if Rails.env.production?
Kernel.abort('The Rails environment is running in staging mode!') if Rails.env.staging?
Kernel.abort('The Rails environment is NOT running in test mode!') unless Rails.env.test?

require 'rspec/collection_matchers'
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'rspec-benchmark'
require 'rspec/mocks'
require 'webmock/rspec'
require 'paperclip/matchers'
require 'database_cleaner/active_record'
require 'database_cleaner/redis'

require 'super_diff/rspec-rails'

require 'support/misc_helper'

require 'fixtures/fixtures'

WEBMOCK_DISABLE_ARGS = { allow_localhost: true, allow: [
  'codeclimate.com',
  Settings.upload_service.public_host,
  Settings.upload_service.admin_host,
  'web'
] }.freeze
WebMock.disable_net_connect!(**WEBMOCK_DISABLE_ARGS)

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

# allow for step based specs
require("#{RSPEC_ROOT}/support/stepwise/stepwise")

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # Database cleaner takes care of this instead
  config.use_transactional_fixtures = false
  config.use_transactional_examples = false

  # RSpec Rails can automatically mix in different behaviors to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behavior by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
  config.define_derived_metadata(file_path: Regexp.new('/spec/(permissions|capabilities)/')) do |metadata|
    metadata[:type] = :request
  end

  # set a random timezone to check for time zone issues
  Zonebie.set_random_timezone
  puts "===> Time zone offset is #{Time.zone.utc_offset}."

  require_relative 'support/metadata_state'
  config.include MetadataState

  require 'support/temp_file_helper'
  config.include TempFileHelpers::Example

  require 'support/path_helpers'
  config.include PathHelpers::Example

  require_relative 'support/logger_helper'
  config.extend LoggerHelpers::ExampleGroup
  config.include LoggerHelpers::Example

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::ControllerHelpers, type: :helper
  config.include Paperclip::Shoulda::Matchers
  config.include FactoryBot::Syntax::Methods
  require_relative 'support/factory_bot_helpers'
  config.include FactoryBotHelpers::Example

  require 'active_storage_validations/matchers' # need to kick start the auto loader for some reason
  config.include ActiveStorageValidations::Matchers, { type: :model }

  config.include RSpec::Benchmark::Matchers

  require_relative 'support/audio_helper'
  config.include AudioHelper::Example

  require_relative 'support/harvest_item_helpers'
  config.include HarvestItemHelper::Example

  require_relative 'support/migrations_helper'
  config.include MigrationsHelpers, :migration

  require_relative 'support/creation_helper'
  config.extend Creation::ExampleGroup
  config.include Creation::Example

  require_relative 'support/mailer_helpers'
  config.extend MailerHelpers::ExampleGroup
  config.include MailerHelpers::Example

  require_relative 'support/citizen_science_creation_helper'
  config.extend CitizenScienceCreation::ExampleGroup

  require 'enumerize/integrations/rspec'
  extend Enumerize::Integrations::RSpec

  require_relative 'support/instrumentation/controller_watcher'
  config.extend ControllerWatcher::ExampleGroup, { type: :request }
  config.include ControllerWatcher::Example, { type: :request }

  require_relative 'support/request_spec_helpers'
  config.extend RequestSpecHelpers::ExampleGroup, { type: :request }
  config.include RequestSpecHelpers::Example, { type: :request }

  require_relative 'support/web_server_helper'

  require_relative 'support/resque_helpers'
  config.extend ResqueHelpers::ExampleGroup
  config.include ResqueHelpers::Example

  require_relative 'support/pbs_helpers'
  # Not done by default because our standard before/after cleanup here adds a
  # lot of overhead to the tests - especially given it's done via a SSH connection
  #config.extend PBSHelpers::ExampleGroup
  #config.include PBSHelpers::Example

  require_relative 'support/api_spec_helpers'
  config.extend ApiSpecHelpers::ExampleGroup, { file_path: Regexp.new('/spec/api/') }
  require_relative 'support/shared_context/api_spec_shared_context'
  config.include_context 'with api shared context', { file_path: Regexp.new('/spec/api/') }

  require_relative 'support/permissions_helper'
  config.extend PermissionsHelpers::ExampleGroup, {
    file_path: Regexp.new('/spec/permissions/')
  }
  require_relative 'support/capabilities_helper'
  config.extend CapabilitiesHelper::ExampleGroup, {
    file_path: Regexp.new('/spec/capabilities')
  }

  require_relative 'support/image_helpers'
  require_relative 'support/sql_helpers'

  require_relative 'support/shared_examples/a_route_that_stores_images'
  require_relative 'support/shared_examples/permissions_for'
  require_relative 'support/shared_examples/capabilities_for'
  require_relative 'support/shared_examples/a_stats_bucket'
  require_relative 'support/shared_examples/a_stats_segment_incrementor'
  require_relative 'support/shared_examples/our_api_routing_patterns'
  require_relative 'support/shared_examples/an_archivable_route'
  require_relative 'support/shared_examples/a_documented_archivable_route'
  require_relative 'support/shared_examples/cascade_deletes_for'

  require "#{RSPEC_ROOT}/support/shared_context/baw_audio_tools_shared"
  require "#{RSPEC_ROOT}/support/shared_context/shared_test_helpers"
  require "#{RSPEC_ROOT}/support/shared_context/async_context"
  require "#{RSPEC_ROOT}/support/shared_context/logger_spy"

  require_relative 'support/matchers/be_same_file_as'
  require_relative 'support/matchers/string_to_have_encoding'

  # change the default creation strategy
  # Previous versions of factory bot would ensure associations used the :create
  # strategy, even if were built (:build). This  behavior is misleading since
  # the database is accessed and objects are saved even though the parent factory
  # was set to *not* save things via a build call.
  # The default changed in FactoryBot 5 so that if build is called all associations
  # will use the build strategy.
  # Unfortunately for us this broke hundreds of tests. Since our priority right
  # now is not hand editing 100s of factory invocations were going to revert to
  # the old behavior.
  # See https://github.com/thoughtbot/factory_bot/blob/master/GETTING_STARTED.md#build-strategies-1
  FactoryBot.use_parent_strategy = false

  sftpgo_tables = ActiveRecord::Base.connection.tables.grep(/sftpgo.*/)
  DEFAULT_CLEANING_STRATEGY = :transaction
  DELETION_CLEANING_STRATEGY = [:deletion, { except: sftpgo_tables }].freeze
  config.before(:suite) do
    # if Rails.env == 'test'
    #   ActiveRecord::Tasks::DatabaseTasks.drop_current
    #   ActiveRecord::Tasks::DatabaseTasks.create_current
    #   ActiveRecord::Tasks::DatabaseTasks.load_schema_current
    # end

    # https://github.com/DatabaseCleaner/database_cleaner
    DatabaseCleaner[:active_record].strategy = DEFAULT_CLEANING_STRATEGY

    DatabaseCleaner[:redis].db = Redis.new(Settings.redis.connection.to_h)
    DatabaseCleaner[:redis].strategy = :deletion

    DatabaseCleaner[:active_record].clean_with(:truncation, { except: sftpgo_tables })
    DatabaseCleaner[:redis].clean

    begin
      DatabaseCleaner.start
      puts '===> Database cleaner: start.'
    ensure
      DatabaseCleaner.clean
      puts '===> Database cleaner: cleaned.'
    end

    # Load seeds for test db
    begin
      Rails.application.load_seed
    rescue Exception => e
      puts 'failure while loading seeds'
      puts e
      puts e.full_message(highlight: true, order: :top)
      exit 1
    end
  end

  config.before type: :request do
    # If this is not set, when the controllers do redirects they will now throw unsafe redirect errors
    host! "#{Settings.host.name}:#{Settings.host.port}"
  end

  config.after type: :request do
    # clear paperclip attachments from tmp directory
    FileUtils.rm_rf(Dir[Rails.root.join('tmp/paperclip/[^.]*').to_s])
  end
  example_logger = SemanticLogger[RSpec]

  config.before do |example|
    # ensure any email is cleared
    ActionMailer::Base.deliveries.clear
    DatabaseCleaner[:active_record].strategy =
      if example.metadata[:clean_by_truncation]
        DELETION_CLEANING_STRATEGY
      elsif example.metadata[:no_database_cleaning]
        nil
      else
        DEFAULT_CLEANING_STRATEGY
      end
    example_logger.info("DatabaseCleaner[:active_record] strategy is: #{DatabaseCleaner[:active_record].strategy}")

    # start database cleaner
    DatabaseCleaner.start unless example.metadata.key?(:no_database_cleaning)
  end

  config.after do |example|
    Temping.teardown

    DatabaseCleaner.clean unless example.metadata.key?(:no_database_cleaning)
    strategy = DatabaseCleaner[:active_record].strategy
    if strategy.is_a?(DatabaseCleaner::ActiveRecord::Truncation) || strategy.is_a?(DatabaseCleaner::ActiveRecord::Deletion)
      Admin::SiteSetting.reset_all_settings!
      Rails.application.load_seed
    else
      Admin::SiteSetting.clear_cache
    end

    Warden.test_reset!

    Resque.redis.close
    BawWorkers::Config.redis_communicator.redis.close
    # some of our tests make use of threads or fibers that can hold onto connections
    # so disconnect everything after each test
    ActiveRecord::Base.connection_pool.disconnect!
  end

  config.around do |example|
    example_description = example.description
    example_logger.info("BEGIN #{example_description}\n")
    example_logger.measure_debug("END #{example_description}") {
      example.run
    }
  end

  # n+1 query detection
  # configuration in config/environments/test.rb
  if Bullet.enable?
    config.before do
      Bullet.start_request
    end

    config.after do
      Bullet.perform_out_of_channel_notifications if Bullet.notification?
      Bullet.end_request
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
