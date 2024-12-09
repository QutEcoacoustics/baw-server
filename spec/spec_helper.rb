# frozen_string_literal: true

# This file was generated by the `rails generate rspec:install` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# The generated `.rspec` file contains `--require spec_helper` which will cause
# this file to always be loaded, without a need to explicitly require it in any
# files.
#
# Given that it is always loaded, you are encouraged to keep this file as
# light-weight as possible. Requiring heavyweight dependencies from this file
# will add to the boot time of your test suite on EVERY test run, even for an
# individual file that may not need all of that loaded. Instead, consider making
# a separate helper file that requires the additional dependencies and performs
# the additional setup, and require it from the spec files that actually need
# it.
#
# The `.rspec` file also contains a few flags that are not defaults but that
# users commonly want.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

ENV['RUNNING_RSPEC'] = true.to_s
RSPEC_ROOT = File.dirname __FILE__

# in order: debase, readapt, ruby/debug, ruby/debug
# rubocop:disable Lint/Debugger
DEBUGGING =  defined?(Debugger) || defined?(Readapt) || defined?(DEBUGGER__) || defined?(debugger)

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://myronmars.to/n/dev-blog/2012/06/rspecs-new-expectation-syntax
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://myronmars.to/n/dev-blog/2014/05/notable-changes-in-rspec-3#new__config_option_to_disable_rspeccore_monkey_patching
  # needed for rspec_api_documentation
  #config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]

    # Configures the maximum character length that RSpec will print while
    # formatting an object
    c.max_formatted_output_length = 1000
  end

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # ensure gem paths are not shown in error backtraces
  config.backtrace_exclusion_patterns.push(%r{/\.rvm/gems/})
  config.backtrace_exclusion_patterns.push(%r{/\.rvm/rubies/})

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  #config.include FactoryBot::Syntax::Methods

  # redirect puts into a text file
  if DEBUGGING
    puts '$stdout and $stderr will NOT be redirected'
  else
    original_stderr = $stderr
    original_stdout = $stdout

    config.before(:suite) do
      # Redirect stderr and stdout
      puts '$stdout and $stderr redirected to log files in ./logs/rspec_*.txt'
      $stderr = File.new(File.join(File.dirname(__FILE__), '..', 'log', 'rspec_stderr.test.log'), 'w')
      $stdout = File.new(File.join(File.dirname(__FILE__), '..', 'log', 'rspec_stdout.test.log'), 'w')
    end

    config.after(:suite) do
      $stderr = original_stderr
      $stdout = original_stdout
    end
  end
  # rubocop:enable Lint/Debugger

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run_when_matching :focus
  config.run_all_when_everything_filtered = false

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = 'tmp/spec/examples_status.txt'

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  RSpec::Matchers.define_negated_matcher :not_eq, :eq
  RSpec::Matchers.define_negated_matcher :exclude, :include
  RSpec::Matchers.define_negated_matcher :a_hash_excluding, :include
  RSpec::Matchers.define_negated_matcher :a_collection_excluding, :include
end
