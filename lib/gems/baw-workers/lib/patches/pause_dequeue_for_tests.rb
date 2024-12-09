# frozen_string_literal: true

if BawApp.test?
  module BawWorkers
    # this is a monkey patch because Resque does not run the before|after_dequeue
    # hooks when a worker reserves a job, only when a job is removed from the queue
    # See
    # https://github.com/resque/resque/issues/512
    # And the inspiration for this patch:
    # https://github.com/rringler/resque-serializer/blob/master/lib/resque-serializer/monkey_patches/resque.rb
    module ResquePatch
      # Manipulate a flag that controls whether jobs are dequeued
      module PauseDequeueForTests
        VERSION = 0.2

        TEST_PERFORM_LOCK_KEY = 'plugins:pause_dequeue_for_test:perform_count'
        TEST_PERFORM_PAUSED = '0'
        TEST_PERFORM_UNLOCKED = '-1'

        include SemanticLogger::Loggable

        # Set a number of jobs workers should be allowed to process
        # @param [Integer] count the number of jobs that will be allowed to dequeue.
        # @return [(String, Boolean)] the response from redis
        def self.set_perform_count(count)
          Resque.redis.set(
            TEST_PERFORM_LOCK_KEY,
            count
          )
        end

        # Increment the number of jobs workers should be allowed to process
        # Use this in a non-blocking scenario, otherwise subsequent calls to allow more jobs to run will just overwrite
        # the current value.
        # @param [Integer] count the number of jobs that will be allowed to dequeue.
        # @return [Integer] the new value
        def self.increment_perform_count(count)
          Resque.redis.incrby(
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

        def self.should_dequeue_job?
          #  Called with the job args before a job is removed from the queue.
          # If the hook returns false, the job will not be removed from the queue.

          should_dequeue = Resque.redis.get(TEST_PERFORM_LOCK_KEY)

          case should_dequeue
          when TEST_PERFORM_PAUSED
            # Do not dequeue. Wait for next round. This is the pause.
            logger.debug('did not execute job because work is paused', test_perform: should_dequeue)
            false
          when TEST_PERFORM_UNLOCKED, nil
            # Act like this plugin is not activated. Do nothing.
            logger.info('ran a job immediately because work is NOT paused', test_perform: should_dequeue)
            true
          when ->(x) { !x.to_i_strict.nil? }
            # We encountered a integer, indicating a number of jobs to complete

            # in this case, the integer will be above 0 or else we are in an invalid state
            to_do = should_dequeue.to_i
            if to_do <= 0
              raise ArgumentError,
                "BawWorkers::ResquePatch::PauseDequeueForTests encountered an unexpected value in its locking key: `#{should_dequeue}` should be greater than 0"
            end

            # decrement the counter by 1, to process one job for this pass
            remaining = Resque.redis.decr(TEST_PERFORM_LOCK_KEY)

            logger.info('will run a job', test_perform: should_dequeue, jobs_remaining: remaining)

            # finally allow the job to run
            true
          else
            raise ArgumentError,
              "BawWorkers::ResquePatch::PauseDequeueForTests encountered an unexpected value in its locking key: `#{should_dequeue}`"
          end
        end
      end

      # The actual monkey patch
      module PauseDequeue
        # NOTE: `Resque#pop` is called when working queued jobs via the
        # `resque:work` rake task.
        # Original: https://github.com/resque/resque/blob/c19d9e2409847ce0d3f56ec56c3091cfa11581bc/lib/resque.rb#L357
        def pop(queue)
          first_item = Resque.redis.peek_in_queue(queue, 0, 1)

          # don't do our fanciness unless there is something in the queue
          return nil if !first_item.nil? && !PauseDequeueForTests.should_dequeue_job?

          super
        end
      end
    end
  end
  Resque.alias_method :__pop, :pop
  # Patch all resque jobs (global so we can catch jobs defined by third parties like ActiveJob)
  Resque.prepend(BawWorkers::ResquePatch::PauseDequeue)
  puts 'PATCH: BawWorkers::Resque::PauseDequeue applied to ::Resque'

  raise 'Resque has not been patched for tests' unless Resque.include?(BawWorkers::ResquePatch::PauseDequeue)
else
  puts 'PATCH: BawWorkers::Resque::PauseDequeue NOT applied'
end
