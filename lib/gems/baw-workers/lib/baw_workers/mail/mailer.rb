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
        job = { job_class: klass, job_args: args, job_queue: queue_name }

        mail_ready = BawWorkers::Mail::Mailer.error_notification(to, from, job, error)
        mail_ready.deliver_now
      end

      def error_notification(to, from, job, error)
        raise ArgumentError, "Error is not a ruby error object #{error.inspect}." unless error.is_a?(StandardError)
        raise ArgumentError, "From is not a string #{from.inspect}." unless from.is_a?(String)
        raise ArgumentError, "To is not a string or Array #{to.inspect}." unless to.is_a?(String) || to.is_a?(Array)
        raise ArgumentError, "Job is not a hash #{job.inspect}." unless job.is_a?(Hash)

        set_view_model(job, error)

        subject = "[#{@details[:host]}]#{Settings.mailer.emails.email_prefix} #{@details[:error_message]}"

        mail(to: to, from: from, subject: subject, content_type: 'text/html') do |format|
          format.html
          format.text
        end
      end

      def set_view_model(job, error)
        job_class = job&.dig(:job_class)
        job_args = job&.dig(:job_args)
        job_queue = job&.dig(:job_queue)

        message, backtrace =
          if error.blank?
            ['(no message available)', '(no backtrace available)']
          else
            [error.message, error.backtrace || ['(backtrace empty)']]
          end

        @details = {
          host: Socket.gethostname,
          job_class: job_class.nil? ? '(no job class available)' : job_class,
          job_args: job_args.nil? ? '(no job args available)' : job_args,
          job_queue: job_queue.nil? ? '(job queue not available)' : job_queue,
          error_class: error&.class&.name,
          error_message: message,
          error_backtrace: backtrace,
          generated_timestamp: Time.zone.now
        }
      end
    end
  end
end
