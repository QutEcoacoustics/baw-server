# frozen_string_literal: true

# Emails about the state of an export.
class ExportMailer < ApplicationMailer
  # @param [Export] export
  def completed_export_message(export)
    send_message(export, 'Completed export', 'export_complete_message')
  end

  private

  # Construct the email.
  # @param [Export] export
  # @param [string] subject_prefix
  # @param [string] template_name
  def send_message(export, subject_prefix, template_name)
    user_email = User.find(export.creator_id).email

    @info = {
      export:,
      datestamp: Time.zone.now.utc.iso8601
    }

    # Sent to the creator + any additional recipients specified in the settings
    mail(
      to: [user_email].concat(Settings.actions.export.required_recipients).uniq,
      subject: "#{Settings.mailer.emails.email_prefix} [Export] #{subject_prefix}: #{@info[:export].name}.",
      template_path: 'exports_mailer',
      template_name:
    )
  end
end
