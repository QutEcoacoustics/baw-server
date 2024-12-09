# frozen_string_literal: true

# Common base class for all mailers.
class ApplicationMailer < ActionMailer::Base
  default from: Settings.mailer.emails.sender_address
end
