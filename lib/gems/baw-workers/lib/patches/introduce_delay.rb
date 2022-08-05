# frozen_string_literal: true

if BawApp.test?
  module BawWorkers
    module Jobs
      # Module to help jobs to induce artificial delays through semaphores
      module IntroduceDelay
        SEMAPHORE_WAITING = 'WAITING'

        TEST_INTRODUCE_DELAY_KEY = 'introduce_delay_for_test:wait_for'
        TEST_INTRODUCE_DELAY_SEMAPHORE_KEY = 'introduce_delay_for_test:semaphore'

        def self.add_hook(job_class, method)
          raise unless job_class.is_a?(Class)
          raise unless job_class.ancestors.include?(::BawWorkers::Jobs::ApplicationJob)

          # this will raise if method does not exist
          unbound_method = job_class.instance_method(method)

          if BawWorkers::Config.redis_communicator.exists?(TEST_INTRODUCE_DELAY_KEY)
            raise 'Cannot introduce more than one delay at a time'
          end

          BawWorkers::Config.redis_communicator.set(TEST_INTRODUCE_DELAY_KEY, {
            job_class: job_class.name,
            method: unbound_method.name
          })
        end

        def self.remove_hook
          BawWorkers::Config.redis_communicator.delete(TEST_INTRODUCE_DELAY_KEY)
          BawWorkers::Config.redis_communicator.delete(TEST_INTRODUCE_DELAY_SEMAPHORE_KEY)
        end

        def self.find_hook
          BawWorkers::Config.redis_communicator.get(TEST_INTRODUCE_DELAY_KEY)
        end

        def self.waiting?
          BawWorkers::Config.redis_communicator.exists?(TEST_INTRODUCE_DELAY_SEMAPHORE_KEY)
        end

        def self.start_waiting!
          BawWorkers::Config.redis_communicator.set(TEST_INTRODUCE_DELAY_SEMAPHORE_KEY, SEMAPHORE_WAITING)
        end

        def self.stop_waiting!
          BawWorkers::Config.redis_communicator.delete(TEST_INTRODUCE_DELAY_SEMAPHORE_KEY)
        end
      end

      # The IntroducedDelay patch that wraps job methods.
      module IntroduceDelayPatch
        INTRODUCED_DELAY_LOGGER_PREFIX = '!!!IntroducedDelay!!!'

        # when the Job is created, dynamically patch the method in question
        def initialize(...)
          hook = ::BawWorkers::Jobs::IntroduceDelay.find_hook&.with_indifferent_access

          if hook
            hook => {job_class:, method:}
            if job_class == self.class.name
              logger.warn("#{INTRODUCED_DELAY_LOGGER_PREFIX} hooked into method #{method}", class:)
              modification = <<~MODULE
                def #{method}(...)
                  __introduced_delay_wait
                  super
                end
              MODULE
              class_eval(modification, __FILE__, __LINE__)
            end
          end

          super(...)
        end

        def __introduced_delay_wait
          logger.warn("#{INTRODUCED_DELAY_LOGGER_PREFIX} hooked triggered")

          ::BawWorkers::Jobs::IntroduceDelay.start_waiting!

          started = Time.now
          elapsed = 0
          loop do
            logger.warn("#{INTRODUCED_DELAY_LOGGER_PREFIX} waiting", elapsed:)
            sleep 0.1
            elapsed = Time.now - started
            # we have a max 30 second delay in the client, the extra second here adds a little leeway
            if elapsed > 31
              raise "#{INTRODUCED_DELAY_LOGGER_PREFIX} NEVER STOPPED WAITING, timed out after #{elapsed}. Did you forget to call `stop_waiting!`?"
            end
            break unless ::BawWorkers::Jobs::IntroduceDelay.waiting?
          end

          logger.warn("#{INTRODUCED_DELAY_LOGGER_PREFIX} hooked completed, resuming job", elapsed:)
        end
      end
    end
  end

  ActiveSupport.on_load(:active_job) do
    ::BawWorkers::Jobs::ApplicationJob.prepend(BawWorkers::Jobs::IntroduceDelayPatch)
  end
  puts 'BawWorkers::ApplicationJob patched with BawWorkers::Jobs::IntroduceDelay'
else
  puts 'BawWorkers::Jobs::IntroduceDelay loading skipped'
end
