# frozen_string_literal: true

module Baw
  module Rack
    # Patch for RailsSemanticLogger::Rack::Logger
    # See https://github.com/reidmorrison/rails_semantic_logger/issues/250
    module Logger
      def call_app(request, env)
        instrumenter = ActiveSupport::Notifications.instrumenter
        handle = instrumenter.build_handle 'request.action_dispatch', request: request
        instrumenter_finish = lambda {
          handle.finish
        }
        handle.start

        logger.send(self.class.started_request_log_level) { started_request_message(request) }
        status, headers, body = @app.call(env)
        body = ::Rack::BodyProxy.new(body, &instrumenter_finish)
        [status, headers, body]
      rescue Exception
        instrumenter_finish.call
        raise
      end
    end
  end
end

RailsSemanticLogger::Rack::Logger.prepend(Baw::Rack::Logger)

puts 'PATCH: Baw::Rack::Logger applied to RailsSemanticLogger::Rack::Logger'
