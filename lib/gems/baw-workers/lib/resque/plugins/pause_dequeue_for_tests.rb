# frozen_string_literal: true

require "#{__dir__}/../../../../baw-app/lib/baw_app"

raise 'Resque::Plugins::PauseDequeueForTests must not be loaded in a non-test environment!!!' unless BawApp.test?

module Resque
  module Plugins
    module PauseDequeueForTests
      VERSION = 0.1

      TEST_PERFORM_LOCK_KEY = 'plugins:pause_dequeue_for_test:perform_count'
      TEST_PERFORM_PAUSED = 0
      TEST_PERFORM_UNLOCKED = -1

      # Set a number of jobs workers should be allowed to process
      # @param [Integer] count the number of jobs that will be allowed to dequeue.
      # @return [(String, Boolean)] the response from redis
      def self.set_perform_count(count)
        Resque.redis.set(
          TEST_PERFORM_LOCK_KEY,
          count
        )
      end

      # Pauses or unlocks workers.
      # When unlocked workers will dequeue as normal.
      # @param [Boolean] paused if `true` will pause dequeuing, if false will unlock workers to dequeue as normal.
      # @return [(String, Boolean)] the response from redis
      def self.set_paused(paused)
        Resque.redis.set(
          TEST_PERFORM_LOCK_KEY,
          paused ? TEST_PERFORM_PAUSED : TEST_PERFORM_UNLOCKED
        )
      end

      # Checks if workers are paused.
      # @return [Boolean] `true` if they are paused, otherwise `false`.
      def self.paused?
        Resque.redis.get(TEST_PERFORM_LOCK_KEY) == TEST_PERFORM_PAUSED
      end

      def before_dequeue_0_pause_queue_for_test
        # Plugins hooks should not use the hook name but should suffix an identifier. We're using the `before_dequeue` hook.
        # Hooks are then called alphabetically, hence the _0_ in the name to ensure this hook is executed first.

        #  Called with the job args before a job is removed from the queue.
        # If the hook returns false, the job will not be removed from the queue.

        should_dequeue = Resque.redis.get(TEST_PERFORM_LOCK_KEY)
        case should_dequeue
        when TEST_PERFORM_PAUSED
          # Do not dequeue. Wait for next round. This is the pause.
          Resque.logger.info('Resque::Plugins::PauseDequeueForTests did not execute job because work is paused')
          false
        when TEST_PERFORM_UNLOCKED, nil
          # Act like this plugin is not activated. Do nothing.
          Resque.logger.info('Resque::Plugins::PauseDequeueForTests ran a job immediately because work is NOT paused')
          true
        when ->(x) { !Integer(x, 10, exception: false).nil? }
          # We encountered a integer, indicating a number of jobs to complete

          # in this case, the integer will be above 0 or else we are in an invalid state
          to_do = should_dequeue.to_i
          if to_do <= 0
            raise ArgumentError,
                  "Resque::Plugins::PauseDequeueForTests encountered an unexpected value in its locking key: `#{should_dequeue}` should be greater than 0"
          end

          # decrement the counter by 1, to process one job for this pass
          remaining = Resque.redis.decr(to_do - 1)

          Resque.logger.info("Resque::Plugins::PauseDequeueForTests will run a job. There are #{remaining} jobs.")

          # finally allow the job to run
          true
        else
          raise ArgumentError,
                "Resque::Plugins::PauseDequeueForTests encountered an unexpected value in its locking key: `#{should_dequeue}`"
        end
      end
    end
  end
end

# Patch all resque jobs (global so we can catch jobs defined by third parties like ActiveJob)
::Resque::Job.include(Resque::Plugins::PauseDequeueForTests)
puts 'Monkey patched Resque::Job with Resque::Plugins::PauseDequeueForTests'
