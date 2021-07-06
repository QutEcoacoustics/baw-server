# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'

# attempting to prevent trivial mistakes
#ENV['RAILS_ENV'] ||= 'test'
if ENV['RAILS_ENV'] != 'test'
  puts \
    <<~MESSAGE
      ***
      Tests must be run in the test environment.
      The current environment `#{ENV['RAILS_ENV']}` has been changed to `test`.
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
abort('The Rails environment is running in production mode!') if Rails.env.production?
abort('The Rails environment is running in staging mode!') if Rails.env.staging?
abort('The Rails environment is NOT running in test mode!') unless Rails.env.test?

require 'rspec/collection_matchers'
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'rspec-benchmark'
require 'webmock/rspec'
require 'paperclip/matchers'
require 'database_cleaner/active_record'
require 'database_cleaner/redis'

require 'super_diff/rspec-rails'

require 'helpers/misc_helper'
require 'helpers/temp_file_helper'
require 'fixtures/fixtures'

WebMock.disable_net_connect!(allow_localhost: true, allow: [
  'codeclimate.com',
  Settings.upload_service.host
])

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

  # set a random timezone to check for time zone issues
  Zonebie.set_random_timezone
  puts "===> Time zone offset is #{Time.zone.utc_offset}."

  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :view
  config.include Devise::Test::ControllerHelpers, type: :helper
  config.include Paperclip::Shoulda::Matchers
  config.include FactoryBot::Syntax::Methods
  require_relative 'helpers/factory_bot_helpers'
  config.include FactoryBotHelpers::Example

  config.include RSpec::Benchmark::Matchers

  require_relative 'helpers/logger_helper'
  config.extend LoggerHelpers::ExampleGroup
  config.include LoggerHelpers::Example

  require_relative 'helpers/migrations_helper'
  config.include MigrationsHelpers, :migration

  require_relative 'helpers/creation_helper'
  config.extend Creation::ExampleGroup
  config.include Creation::Example

  require_relative 'helpers/citizen_science_creation_helper'
  config.extend CitizenScienceCreation::ExampleGroup

  require 'enumerize/integrations/rspec'
  extend Enumerize::Integrations::RSpec

  require_relative 'helpers/request_spec_helpers'
  config.extend RequestSpecHelpers::ExampleGroup, { type: :request }
  config.include RequestSpecHelpers::Example, { type: :request }

  require_relative 'helpers/resque_helpers'
  config.extend ResqueHelpers::ExampleGroup
  config.include ResqueHelpers::Example

  require_relative 'helpers/api_spec_helpers'
  config.extend ApiSpecHelpers::ExampleGroup, { file_path: Regexp.new('/spec/api/') }
  require_relative 'helpers/shared_context/api_spec_shared_context'
  config.include_context :api_spec_shared_context, { file_path: Regexp.new('/spec/api/') }

  require_relative 'helpers/permissions_helper'
  config.extend PermissionsHelpers::ExampleGroup, {
    file_path: Regexp.new('/spec/requests/permissions')
  }

  require_relative 'helpers/shared_examples/a_route_that_stores_images'
  require_relative 'helpers/shared_examples/permissions_for'

  require "#{RSPEC_ROOT}/helpers/shared_context/baw_audio_tools_shared"

  # Ensure we actually perform jobs with resque.
  # We don't want to run jobs inline, it produces unrealistic tests.
  # https://github.com/rails/rails/issues/37270#issuecomment-558278392
  (ActiveJob::Base.descendants << ActiveJob::Base).each(&:disable_test_adapter)
  Rails.application.config.active_job.queue_adapter = :resque
  ActiveJob::Base.queue_adapter = :resque

  # change the default creation strategy
  # Previous versions of factory but would ensure associations used the :create
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

  config.before(:suite) do
    # if Rails.env == 'test'
    #   ActiveRecord::Tasks::DatabaseTasks.drop_current
    #   ActiveRecord::Tasks::DatabaseTasks.create_current
    #   ActiveRecord::Tasks::DatabaseTasks.load_schema_current
    # end

    # https://github.com/DatabaseCleaner/database_cleaner
    DatabaseCleaner[:active_record].strategy = :transaction

    DatabaseCleaner[:redis].db = Redis.new(Settings.redis.connection.to_h)
    DatabaseCleaner[:redis].strategy = :deletion

    DatabaseCleaner[:active_record].clean_with(:truncation)
    DatabaseCleaner[:redis].clean

    begin
      DatabaseCleaner.start
      puts '===> Database cleaner: start.'
    ensure
      DatabaseCleaner.clean
      puts '===> Database cleaner: cleaned.'
    end

    # Load seeds for test db
    Rails.application.load_seed
  end

  config.before type: :request do
  end

  config.after type: :request do
    # clear paperclip attachments from tmp directory
    FileUtils.rm_rf(Dir["#{Rails.root}/tmp/paperclip/[^.]*"])
  end

  config.before do |_example|
    # ensure any email is cleared
    ActionMailer::Base.deliveries.clear

    # start database cleaner
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean

    Warden.test_reset!
  end

  example_logger = SemanticLogger[RSpec]
  config.around do |example|
    example_description = example.description
    example_logger.info("BEGIN #{example_description}\n")
    example_logger.measure_debug('END') {
      example.run
    }
  end

  # enable options requests in feature tests
  module ActionDispatch
    module Integration
      module RequestHelpers
        # REVIEW: for rails 7: should exist
        def options(path, **args)
          process(:options, path, **args)
        end
      end
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

# load so-called "global" spec steps
Dir.glob(File.expand_path('helpers/steps/**/*steps.rb', __dir__)).each { |f| require f }
# load any step file that is next to a feature file of the same name.
# based on: https://github.com/jnicklas/turnip/pull/96#issuecomment-39579471
RSpec.configure do |config|
  require 'helpers/shared_test_helpers'
  config.include_context 'shared_test_helpers', turnip: true
  config.on_example_group_definition do |group|
    next unless group.metadata.key?(:turnip)

    feature_file = group.file_path

    feature_path = Pathname.new(feature_file)
    feature_directory = feature_path.dirname
    conventional_step_file = feature_directory / "#{feature_path.basename('.*')}_steps.rb"

    if File.exist?(conventional_step_file)
      require conventional_step_file

      conventional_module = conventional_step_file.basename('.*').to_s.split('_').each(&:capitalize!).join
      unless Module.const_defined?(conventional_module)
        raise NameError, "Expected module named `#{conventional_module}` to be defined in #{conventional_step_file}," \
          ' but it has not been loaded. Is it defined?'
      end

      group.include Module.const_get(conventional_module)
    else
      message = ::RSpec::Core::Formatters::ConsoleCodes.wrap(
        "Warning: Did not find conventional step file #{conventional_step_file.basename} for #{feature_path}",
        :yellow
      )
      config.reporter.message(message)
    end
  end
end
