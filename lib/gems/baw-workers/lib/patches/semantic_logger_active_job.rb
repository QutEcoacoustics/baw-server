# frozen_string_literal: true

# The SemanticLogger framework is overly helpful and cannot log more complex
# types in arguments. Since it is noisy anyway, and since the resque logger
# logs the arguments, and since their only customization point is on/off,
# we'll just turn it off
# https://github.com/reidmorrison/rails_semantic_logger/blob/aec7eaf42f692d8b119f458640ea9cc0679f1390/lib/rails_semantic_logger/active_job/log_subscriber.rb#L85-L108

module Baw
  module RailsSemanticLogger
    module ActiveJob
      module LogSubscriber
        # Custom modifications to semantic logger's active job configuration
        module EventFormatter
          # def format(arg)
          #   return super(arg.to_h) if arg.respond_to?(:to_h)

          #   super(arg)
          # end

          def formatted_args
            job.arguments.as_json
          end
        end
      end
    end
  end
end

RailsSemanticLogger::ActiveJob::LogSubscriber::EventFormatter.prepend(
  Baw::RailsSemanticLogger::ActiveJob::LogSubscriber::EventFormatter
)
