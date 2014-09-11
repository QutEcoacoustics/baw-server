require 'socket'
require 'action_mailer'

module BawWorkers
  module Mail
    class Mailer < ActionMailer::Base
      def error_notification(to, from, job, error)

        details = {
            host: Socket.gethostname,
            job_class: job.blank? ? '(no job class available)' : job.job_class,
            job_args: job.blank? ? '(no job args available)' : job.job_args,
            error_message: error.blank? ? '(no message available)' : error.message,
            error_backtrace: error.blank? ? '(no backtrace available)' : error.backtrace,
            generated_timestamp: Time.zone.now
        }

        prepared_email = mail(to: to, from: from, template_path: 'mail',
                              subject: "[#{details.host}][Exception] #{details.error_message}") do |format|
          format.text do
            render text: "Hello,

A resque worker running on #{details.host} encountered a problem.

The running job was:

#{details.job_class}

#{details.job_args}

The error was:

#{details.error_message}

#{details.error_backtrace}

This email was generated at #{details.generated_timestamp}.

Regards, #{details.host }"
          end
          format.html do
            render html: "<p>Hello,</p>

<p>A resque worker running on #{details.host} encountered a problem.</p>

<p>The running job was:</p>

<p>#{details.job_class}</p>

<p>#{details.job_args}</p>

<p>The error was:</p>

<p>#{details.error_message}</p>

<pre><code>#{details.error_backtrace}</code></pre>

<p>This email was generated at #{details.generated_timestamp }.</p>

<p>Regards, #{details.host }</p>"
          end
        end
      end
    end
  end
end