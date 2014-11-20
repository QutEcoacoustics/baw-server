require 'socket'
require 'action_mailer'

module BawWorkers
  module Mail
    class Mailer < ActionMailer::Base

      def send_worker_error_email(klass, args, queue_name, error)
        to = BawWorkers::Settings.mailer.emails.required_recipients
        from = BawWorkers::Settings.mailer.emails.sender_address
        job = {job_class: klass, job_args: args, job_queue: queue_name}

        mail_ready = error_notification(to, from, job, error)
        mail_ready.deliver
      end

      def error_notification(to, from, job, error)
        fail ArgumentError, "Error is not a ruby error object #{error.inspect}." unless error.is_a?(StandardError)
        fail ArgumentError, "From is not a string #{from.inspect}." unless from.is_a?(String)
        fail ArgumentError, "To is not a string or Array #{to.inspect}." unless (to.is_a?(String) || to.is_a?(Array))
        fail ArgumentError, "Job is not a hash #{job.inspect}." unless job.is_a?(Hash)

        details = {
            host: Socket.gethostname,
            job_class: job.blank? || !job.include?(:job_class) ? '(no job class available)' : job[:job_class],
            job_args: job.blank? || !job.include?(:job_args) ? '(no job args available)' : job[:job_args],
            job_queue: job.blank? || !job.include?(:job_queue) ? '(job queue not available)' : job[:job_queue],
            error_message: error.blank? ? '(no message available)' : error.message,
            error_backtrace: error.blank? ? ['(no backtrace available)'] : error.backtrace,
            generated_timestamp: Time.zone.now
        }

        mail(to: to, from: from, template_path: 'mail',
                              subject: "[#{details[:host]}]#{BawWorkers::Settings.mailer.emails.email_prefix} #{details[:error_message]}") do |format|
          format.text do
            render text: "Hello,

A resque worker running on #{details[:host]} encountered a problem.

The running job was:

Queue: #{details[:job_queue]}

Class: #{details[:job_class]}

Arguments: #{details[:job_args]}

The error was:

Error: #{details[:error_message]}

Backtrace: #{details[:error_backtrace].join("\n")}

This email was generated at #{details[:generated_timestamp]}.

Regards, #{details[:host]}"
          end

          format.html do
            render html: "<p>Hello,</p>

<p>A resque worker running on #{details[:host]} encountered a problem.</p>

<p>The running job was:</p>

<p>Queue: #{details[:job_queue]}</p>

<p>Class: #{details[:job_class]}</p>

<p>Arguments: #{details[:job_args]}</p>

<p>The error was:</p>

<p>Error: #{details[:error_message]}</p>

<pre>Backtrace: <code>#{details[:error_backtrace].join('<br>')}</code></pre>

<p>This email was generated at #{details[:generated_timestamp]}.</p>

<p>Regards, #{details[:host]}</p>"
          end
        end

      end
    end
  end
end