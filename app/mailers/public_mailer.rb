# frozen_string_literal: true

class PublicMailer < ApplicationMailer
  default from: Settings.mailer.emails.sender_address

  # @param [User] logged_in_user
  # @param [DataClass::ContactUs] model
  # @param [Hash] request_info client request details ({ remote_ip:, user_agent: })
  def contact_us_message(logged_in_user, model, request_info = {})
    send_message(logged_in_user, model, request_info, 'Contact Us', 'contact_us_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::BugReport] model
  # @param [Hash] request_info client request details ({ remote_ip:, user_agent: })
  def bug_report_message(logged_in_user, model, request_info = {})
    send_message(logged_in_user, model, request_info, 'Bug Report', 'bug_report_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::DataRequest] model
  # @param [Hash] request_info client request details ({ remote_ip:, user_agent: })
  def data_request_message(logged_in_user, model, request_info = {})
    send_message(logged_in_user, model, request_info, 'Data Request', 'data_request_message')
  end

  # @param [User] logged_in_user
  # @param [DataClass::NewUserInfo] model
  def new_user_message(logged_in_user, model)
    send_message(logged_in_user, model, {}, 'New User Notification', 'new_user_message')
  end

  private

  # Construct the email.
  # @param [User] logged_in_user
  # @param [Object] model
  # @param [Hash] request_info client request details ({ remote_ip:, user_agent: })
  # @param [string] subject_prefix
  # @param [string] template_name
  def send_message(logged_in_user, model, request_info, subject_prefix, template_name)
    request_info = (request_info || {}).symbolize_keys

    @info = {
      logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
      model:,
      sender_email: model.email.presence,
      sender_name: model.name.presence || "someone (who didn't include their name)",
      client_ip: request_info[:remote_ip].presence || '',
      client_browser: request_info[:user_agent].presence || '',
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
