# frozen_string_literal: true

require 'socket'
require 'action_mailer'
require 'rack/utils'

module BawWorkers
  module Mail
    class Mailer < ApplicationMailer
      prepend_view_path BawWorkers::ROOT

      def self.logger
        BawWorkers::Config.logger_mailer
      end

      def self.send_worker_error_email(klass, args, queue_name, error)
        to = Settings.mailer.emails.required_recipients
        from = Settings.mailer.emails.sender_address

        # Capture everything we need as plain, serializable values *now*, while we
        # still have the original objects. The email is delivered later via
        # ActiveJob, which cannot serialize arbitrary job/error objects (e.g. a
        # raw exception or class), so the mailer action below only ever receives a
        # hash of strings.
        details = build_details(klass, args, queue_name, error)

        BawWorkers::Mail::Mailer.error_notification(to, from, details).deliver_later
      end

      # Build the serializable view model for an error notification email.
      # @return [Hash] only contains strings, arrays of strings, and a timestamp.
      def self.build_details(klass, args, queue_name, error)
        {
          host: Socket.gethostname,
          job_class: klass.nil? ? '(no job class available)' : klass.to_s,
          job_args: args.nil? ? '(no job args available)' : args.to_s,
          job_queue: queue_name.nil? ? '(job queue not available)' : queue_name.to_s,
          error_class: error&.class&.name,
          error_message: error_message_for(error),
          error_backtrace: error_backtrace_for(error),
          generated_timestamp: Time.zone.now
        }
      end

      def self.error_message_for(error)
        return '(no message available)' if error.blank?

        error.message.to_s
      end

      def self.error_backtrace_for(error)
        return ['(no backtrace available)'] if error.blank?

        Array(error.backtrace).map(&:to_s).presence || ['(backtrace empty)']
      end

      def error_notification(to, from, details)
        raise ArgumentError, "From is not a string #{from.inspect}." unless from.is_a?(String)
        raise ArgumentError, "To is not a string or Array #{to.inspect}." unless to.is_a?(String) || to.is_a?(Array)
        raise ArgumentError, "Details is not a hash #{details.inspect}." unless details.is_a?(Hash)

        @details = details

        subject = "[#{@details[:host]}]#{Settings.mailer.emails.email_prefix} #{@details[:error_message]}"

        mail(to: to, from: from, subject: subject, content_type: 'text/html') do |format|
          format.html
          format.text
        end
      end
    end
  end
end
