# frozen_string_literal: true

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
        host_url = "http://0.0.0.0:#{Settings.api.port}"
        timeout = example.metadata.fetch(:web_server_timeout, 30)

        # start a web server
        task = Async { |inner|
          ready = false
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
          serve_task = inner.async { |inner|
            endpoint = Async::HTTP::Endpoint.parse(host_url)
            server = Falcon::Server.new(
              # falcon logging to stderr leads to the following bug:
              # https://github.com/socketry/async/issues/138
              Falcon::Server.middleware(Rails.application, verbose: false, cache: false),
              endpoint
            )
            server.run
            logger.info('Test web server: running test')
            ready = true

            inner.children.each(&:wait)
          }

          spec_task = inner.async {
            sleep 0.1 until ready
            logger.measure_info('Test web server: running test') do
              example.call
            end

            timer_task.stop
          }

          begin
            timer_task.wait
            spec_task.wait
          ensure
            logger.info('Test web server: closing down')
            serve_task.stop
          end
        }

        logger.info('Test web server: ending hook')
        task.stop
        task.wait
      end
    end
  end
end
