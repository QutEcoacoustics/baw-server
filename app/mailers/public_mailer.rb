# frozen_string_literal: true

class PublicMailer < ApplicationMailer
  default from: Settings.mailer.emails.sender_address

  # @param [User] logged_in_user
  # @param [DataClass::ContactUs] model
  # @param [ActionDispatch::Request] rails_request
  def contact_us_message(logged_in_user, model, rails_request)
    send_message(logged_in_user, model, rails_request, 'Contact Us', 'contact_us_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::BugReport] model
  # @param [ActionDispatch::Request] rails_request
  def bug_report_message(logged_in_user, model, rails_request)
    send_message(logged_in_user, model, rails_request, 'Bug Report', 'bug_report_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::DataRequest] model
  # @param [ActionDispatch::Request] rails_request
  def data_request_message(logged_in_user, model, rails_request)
    send_message(logged_in_user, model, rails_request, 'Data Request', 'data_request_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::NewUserInfo] model
  def new_user_message(logged_in_user, model)
    send_message(logged_in_user, model, nil, 'New User Notification', 'new_user_message')
  end

  private

  # Construct the email.
  # @param [User] logged_in_user
  # @param [Object] model
  # @param [ActionDispatch::Request] rails_request
  # @param [string] subject_prefix
  # @param [string] template_name
  def send_message(logged_in_user, model, rails_request, subject_prefix, template_name)
    @info = {
      logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
      model:,
      sender_email: model.email.presence,
      sender_name: (model.name.presence || "someone (who didn't include their name)"),
      client_ip: rails_request.blank? ? '' : rails_request.remote_ip,
      client_browser: rails_request.blank? ? '' : rails_request.user_agent,
      datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (e.g. admins)
    mail(
      to: Settings.mailer.emails.required_recipients,
      subject: "#{Settings.mailer.emails.email_prefix} [#{subject_prefix}] Form submission from #{@info[:sender_name]}.",
      template_path: 'public_mailer',
      template_name:
    )
  end
end
