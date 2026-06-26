# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Mail
      # Delivers a pre-rendered (raw RFC 2822) email asynchronously on the mailer
      # queue. Used to make otherwise-synchronous senders (e.g. the exception
      # notifier) route their actual SMTP delivery through a mail-capable worker.
      class DeliverRawEmailJob < BawWorkers::Jobs::ApplicationJob
        queue_as Settings.actions.mailer.queue

        perform_expects String

        # Never let an email-delivery failure propagate to Resque::Failure: the
        # ExceptionNotification Resque backend fires ExceptionNotifier on every
        # failed job, which would enqueue another delivery job and loop forever
        # whenever the mail server is unreachable. Log and drop instead. This
        # deliberately overrides the inherited `discard_on(StandardError, &:notify_error)`.
        discard_on(StandardError) do |job, error|
          job.logger.error('Failed to deliver email', error)
        end

        # @param [String] raw_email the encoded RFC 2822 message to deliver
        # @return [void]
        def perform(raw_email)
          message = ::Mail.new(raw_email)
          # Wire up ActionMailer's configured delivery method (smtp in production,
          # test in specs) so delivery settings and `ActionMailer::Base.deliveries`
          # apply just as they would for a normal mailer.
          ActionMailer::Base.wrap_delivery_behavior(message)
          message.deliver
        end

        def create_job_id
          BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          @name ||= job_id
        end
      end
    end
  end
end
