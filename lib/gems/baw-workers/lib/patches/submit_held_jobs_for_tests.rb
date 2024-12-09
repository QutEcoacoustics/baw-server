# frozen_string_literal: true

require 'amazing_print'

if BawApp.test?
  module BawWorkers
    # modify PBS job submission to allow for testing - held jobs give us a chance
    # to test the jobs one step at a time.
    module PBS
      module Connection
        # Manipulate a flag that controls whether jobs are dequeued
        module SubmitHeldJobsForTests
          TEST_HELD_KEY = 'submit_held_jobs_for_pbs_tests:should_hold'
          TEST_HELD = 'held'

          include SemanticLogger::Loggable

          # Pauses or unlocks workers.
          # When unlocked workers will dequeue as normal.
          # @param [Boolean] held if `true` will pause dequeuing, if false will unlock workers to dequeue as normal.
          # @return [Boolean,nil] the response from redis
          def self.modify_should_hold(held)
            BawWorkers::Config.redis_communicator.set(TEST_HELD_KEY, TEST_HELD) if held

            BawWorkers::Config.redis_communicator.delete(TEST_HELD_KEY) unless held
          end

          # Checks if workers are paused.
          # @return [Boolean] `true` if they are paused, otherwise `false`.
          def self.paused?
            BawWorkers::Config.redis_communicator.get(TEST_HELD_KEY) == TEST_HELD
          end
        end

        # The SubmitHeldPatch patch that wraps job methods.
        module SubmitHeldPatch
          SUBMIT_HELD_LOGGER_PREFIX = AmazingPrint::Colors.yellow('!!!SubmitHeldPatch!!!')
          JOB_HELD = AmazingPrint::Colors.yellow(' JOB HELD')

          # The patch for {PBS::Connection#submit_job}
          def submit_job(*args, **keyword_args)
            if SubmitHeldJobsForTests.paused?

              keyword_args[:hold] = true
              result = super(*args, **keyword_args)
              logger.warn("#{SUBMIT_HELD_LOGGER_PREFIX} submit_job modified: #{JOB_HELD}", job_id: result.fmap(&:first))
              return result
            end

            logger.debug("#{SUBMIT_HELD_LOGGER_PREFIX} submit_job not modified: submitting as normal")
            super(*args, **keyword_args)
          end
        end
      end
    end
  end

  PBS::Connection.prepend(BawWorkers::PBS::Connection::SubmitHeldPatch)
  puts 'PATCH: BawWorkers::PBS::Connection::SubmitHeldPatch applied to ::PBS::Connection'
else
  puts 'PATCH: BawWorkers::PBS::Connection::SubmitHeldPatch NOT applied'
end
