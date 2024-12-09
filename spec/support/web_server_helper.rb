# frozen_string_literal: true

require 'English'
module WebServerHelper
  # config.extend allows these methods to be used in describe/context groups
  module ExampleGroup
    # Start a web server that uses the current Rails.application as the Rack app.
    # Use in integration tests where you need external services/programs/jobs to
    # interact with the test session via HTTP.
    # - The database cleaner transaction strategy is still effective
    #   i.e. a http request from an external service will still see the current
    #   state of the database inside the test transaction!
    # - You can use mocks to manipulate server side classes
    # - It is fast too. For each test it does not restart Rails, just the Rack
    #   server and port binding.
    def expose_app_as_web_server
      around do |example|
        current_example = RSpec.current_example
        host_url = "http://0.0.0.0:#{Settings.host.port}"
        timeout = example.metadata.fetch(:web_server_timeout, 30)
        timeout = 3600 if DEBUGGING
        logger = SemanticLogger[Falcon]

        # start a web server
        task = Async { |inner|
          ready = Async::Condition.new
          timer_task = inner.async { |task|
            # Wait for the timeout, at any point this task might be cancelled if the user code completes:
            task.annotate("Timer task duration=#{timeout}.")
            task.sleep(timeout)

            # The timeout expired, so generate an error:
            buffer = StringIO.new
            task.print_hierarchy(buffer)

            # Raise an error so it is logged:
            raise Async::TimeoutError, "Run time exceeded timeout #{timeout}s:\n#{buffer.string}"
          }
          serve_task = inner.async { |_inner|
            endpoint = Async::HTTP::Endpoint.parse(host_url)
            server = Falcon::Server.new(
              Falcon::Server.middleware(
                Rails.application,
                verbose: false,
                cache: false
              ),
              endpoint
            )
            reactor = server.run
            logger.info('Test web server: started web server')
            ready.signal(true)
            if reactor.respond_to?(:each)
              reactor.each(&:wait)
            else
              reactor.wait
            end

            #inner.children.each(&:wait)
          }

          spec_task = inner.async {
            logger.info('Test web server: waiting for web server')

            ready.wait

            logger.measure_info('Test web server: running test') do
              # This state seems to be lost across the thread boundary.
              # The rest of Rspec.world seems to be fine though.

              RSpec.current_example = current_example
              #logger.info('Test web server: before example')

              result = example.call
              #logger.info('Test web server: after example', result:)
              result
            end

            timer_task.stop
          }

          begin
            timer_task.wait
            #logger.info('Test web server: timer finished server')
            spec_task.wait
            #logger.info('Test web server: spec finished')
          rescue StandardError, Async::Stop => e
            # sometimes error's happen in the ensure block
            # which mask the true errors... so log it again here just in case
            logger.error('Test web server: error during test', exception: e)
            raise
          ensure
            logger.info('Test web server: closing down')
            serve_task.stop
          end
        }

        logger.info('Test web server: ending hook')
        #task.stop
        task.wait
      end
    end
  end
end
