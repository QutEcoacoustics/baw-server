class PublicMailer < ActionMailer::Base
  default from: Settings.emails.sender_address

  # @param [User] logged_in_user
  # @param [ContactUs] model
  # @param [ActionDispatch::Request] rails_request
  def contact_us_message(logged_in_user, model, rails_request)

    @feedback_info = {
        logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
        content: model.content,
        sender_email: model.email.blank? ? nil : model.email,
        sender_name: model.name.blank? ? 'Someone' : model.name,
        client_ip: rails_request.remote_ip,
        client_browser: rails_request.user_agent,
        datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (e.g. admins)
    mail(
        to: Settings.emails.required_recipients,
        subject: "#{Settings.emails.email_prefix} [Contact Us] #{@feedback_info[:sender_name]} sent a message from the Contact Us page."
    ).deliver
  end

  # @param [User] logged_in_user
  # @param [BugReport] model
  # @param [ActionDispatch::Request] rails_request
  def bug_report_message(logged_in_user, model, rails_request)

    @feedback_info = {
        logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
        description: model.description,
        content: model.content,
        sender_email: model.email.blank? ? nil : model.email,
        sender_name: model.name.blank? ? 'Someone' : model.name,
        client_ip: rails_request.remote_ip,
        client_browser: rails_request.user_agent,
        datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (e.g. admins)
    mail(
        to: Settings.emails.required_recipients,
        subject: "#{Settings.emails.email_prefix} [Bug Report] #{@feedback_info[:sender_name]} submitted a bug report."
    ).deliver
  end

  # @param [User] logged_in_user
  # @param [DataRequest] model
  # @param [ActionDispatch::Request] rails_request
  def data_request_message(logged_in_user, model, rails_request)

    @feedback_info = {
        logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
        group: model.group,
        group_type: model.group_type,
        content: model.content,
        sender_email: model.email.blank? ? nil : model.email,
        sender_name: model.name.blank? ? 'Someone' : model.name,
        client_ip: rails_request.remote_ip,
        client_browser: rails_request.user_agent,
        datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (e.g. admins)
    mail(
        to: Settings.emails.required_recipients,
        subject: "#{Settings.emails.email_prefix} [Data Request] #{@feedback_info[:sender_name]} submitted a data request."
    ).deliver
  end

end