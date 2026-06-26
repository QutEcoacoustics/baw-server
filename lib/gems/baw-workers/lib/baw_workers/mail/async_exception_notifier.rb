# frozen_string_literal: true

require 'exception_notification'

module BawWorkers
  module Mail
    # An ExceptionNotification email notifier that builds the notification email
    # synchronously (it needs the live exception, request and env, which cannot be
    # serialized for ActiveJob) but delivers it asynchronously on the mailer
    # queue, so that only mail-capable workers perform the actual SMTP send.
    # See issue #1004.
    class AsyncExceptionNotifier < ExceptionNotifier::EmailNotifier
      # @param [Exception] exception
      # @param [Hash] options
      # @return [void]
      def call(exception, options = {})
        message = create_email(exception, options)
        return if message.nil?

        BawWorkers::Jobs::Mail::DeliverRawEmailJob.perform_later(message.message.encoded)
      end
    end
  end
end
