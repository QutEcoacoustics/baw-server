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
      rescue StandardError
        instrumenter_finish.call
        raise
      end
    end
  end

  module ActiveRecord
    # https://github.com/reidmorrison/rails_semantic_logger/issues/249
    module LogSubscriber
      # just aliasing some methods because the version detection is broken
      def self.included(base)
        base.alias_method(:bind_values, :bind_values_v6_1)
        base.alias_method(:render_bind, :render_bind_v6_1)
        base.alias_method(:type_casted_binds, :type_casted_binds_v5_1_5)
      end
    end
  end
end

RailsSemanticLogger::Rack::Logger.prepend(Baw::Rack::Logger)
RailsSemanticLogger::ActiveRecord::LogSubscriber.include(Baw::ActiveRecord::LogSubscriber)

if Gem.loaded_specs['rails_semantic_logger'].version > Gem::Version.new('4.17.0')
  raise 'PATCH: revaluate if patches in /home/baw_web/baw-server/lib/patches/rails_sementic_logger.rb are still needed, as they may have been fixed in rails_semantic_logger'

end

puts 'PATCH: Baw::Rack::Logger applied to RailsSemanticLogger::Rack::Logger'
puts 'PATCH: Baw::ActiveRecord::LogSubscriber applied to RailsSemanticLogger::ActiveRecord::LogSubscriber'
