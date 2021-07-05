# frozen_string_literal: true

# - if we're running tests, then we want our workers to really do jobs
# - on the worker, we don't want test helpers interfering
# - thus we nuke the rails included test helpers if the RUNNING_RSPEC variable is missing
# - RUNNING_RSPEC is only defined by the test runner, which is on the web-server container, and not the worker container
# Related to  https://github.com/rails/rails/issues/37270
if !ENV.key?('RUNNING_RSPEC') && defined?(::ActiveJob::TestHelper)
  puts 'Monkey patch: removing constant ::ActiveJob::TestHelper'

  ::ActiveJob.send(:remove_const, :TestHelper)

  module ActiveJob
    module TestHelper
      module TestQueueAdapter
        extend ActiveSupport::Concern

        module ClassMethods
          def queue_adapter # rubocop:disable
            # intentional noop - rubocop keeps removing this method, but it needs to be here
            _noop = :noop
            super
          end

          def disable_test_adapter
            warn('intentionally broken in lib/gems/baw-workers/lib/patches/disable_test_adapter.rb')
          end

          def enable_test_adapter(_test_adapter)
            warn('intentionally broken in lib/gems/baw-workers/lib/patches/disable_test_adapter.rb')
          end
        end
      end
    end
  end
end
