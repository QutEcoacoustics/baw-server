class AnalysisJobMailer < ActionMailer::Base
  default from: Settings.mailer.emails.sender_address

  # @param [AnalysisJob] analysis_job
  # @param [ActionDispatch::Request] rails_request
  def new_job_message(analysis_job, rails_request)
    send_message(analysis_job, rails_request, 'New analysis job', 'analysis_job_new_message')
  end

  # @param [AnalysisJob] analysis_job
  # @param [ActionDispatch::Request] rails_request
  def completed_job_message(analysis_job, rails_request)
    send_message(analysis_job, rails_request, 'Completed analysis job', 'analysis_job_complete_message')
  end

  # @param [AnalysisJob] analysis_job
  # @param [ActionDispatch::Request] rails_request
  def retry_job_message(analysis_job, rails_request)
    send_message(analysis_job, rails_request, 'Retrying analysis job', 'analysis_job_retry_message')
  end

  private

  # Construct the email.
  # @param [AnalysisJob] analysis_job
  # @param [ActionDispatch::Request] rails_request
  # @param [string] subject_prefix
  # @param [string] template_name
  def send_message(analysis_job, rails_request, subject_prefix, template_name)
    user_emails = User.find([analysis_job.creator_id, analysis_job.updater_id]).map {|u| u.email }.uniq

    @info = {
        analysis_job: analysis_job,
        datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (creator, updater, admins)
    mail(
        to: user_emails.concat(Settings.mailer.emails.required_recipients).uniq,
        subject: "#{Settings.mailer.emails.email_prefix} [#{subject_prefix}] #{@info[:analysis_job].name}.",
        template_path: 'analysis_jobs_mailer',
        template_name: template_name)
  end

end