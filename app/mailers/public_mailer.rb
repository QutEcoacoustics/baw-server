class PublicMailer < ActionMailer::Base
  default from: Settings.emails.sender_address

  # @param [User] logged_in_user
  # @param [ContactUs] contact_us_model
  # @param [ActionDispatch::Request] rails_request
  def contact_us_message(logged_in_user, contact_us_model, rails_request)

    # request.user_agent
    # request.client_ip

    @feedback_info = {
        logged_in_user_name: logged_in_user.blank? ? nil : logged_in_user.user_name,
        content: contact_us_model.content,
        sender_email: contact_us_model.email.blank? ? nil : contact_us_model.email,
        sender_name: contact_us_model.name.blank? ? 'Someone' : contact_us_model.name,
        client_ip: rails_request.remote_ip,
        client_browser: rails_request.user_agent,
        datestamp: Time.zone.now.utc.iso8601
    }

    # email gets sent to required recipients (e.g. admins)
    mail(
        to: Settings.emails.required_recipients,
        subject: "#{Settings.emails.email_prefix} #{@feedback_info[:sender_name]} sent a message from the Contact Us page."
    ).deliver
  end

  private

  def send_feedback

  end
end