# frozen_string_literal: true

require 'exception_notification/rails'

# resque failures are emailed just like exceptions from Rails.
require 'resque/failure/multiple'
require 'resque/failure/redis'
require 'exception_notification/resque'

Resque::Failure::Multiple.classes = [Resque::Failure::Redis, ExceptionNotification::Resque]
Resque::Failure.backend = Resque::Failure::Multiple

ExceptionNotification.configure do |config|
  # Ignore additional exception types.
  # ActiveRecord::RecordNotFound, AbstractController::ActionNotFound and ActionController::RoutingError are already added.
  # config.ignored_exceptions += %w{ActionView::TemplateError CustomError}

  # Adds a condition to decide when an exception must be ignored or not.
  # The ignore_if method can be invoked multiple times to add extra conditions.
  # config.ignore_if do |exception, options|
  #   not Rails.env.production?
  # end

  # Notifiers =================================================================

  # Email notifier sends notifications by email.
  # We deliver these emails asynchronously via the mailer queue so that only
  # mail-capable workers perform the actual SMTP send (see issue #1004). The
  # email must be *built* synchronously because it needs the live exception,
  # request and env which can't be serialized for ActiveJob, so the custom
  # notifier renders the message now and enqueues a job to send the raw message.
  config.add_notifier :email, BawWorkers::Mail::AsyncExceptionNotifier.new(
    email_prefix: "#{Settings.mailer.emails.email_prefix} [Exception] ",
    sender_address: Settings.mailer.emails.sender_address,
    exception_recipients: Settings.mailer.emails.required_recipients
  )

  # can't reliably test email delivery if repeated mail in test suites is squashed
  config.error_grouping = !BawApp.dev_or_test?

  # Campfire notifier sends notifications to your Campfire room. Requires 'tinder' gem.
  # config.add_notifier :campfire, {
  #   :subdomain => 'my_subdomain',
  #   :token => 'my_token',
  #   :room_name => 'my_room'
  # }

  # HipChat notifier sends notifications to your HipChat room. Requires 'hipchat' gem.
  # config.add_notifier :hipchat, {
  #   :api_token => 'my_token',
  #   :room_name => 'my_room'
  # }

  # Webhook notifier sends notifications over HTTP protocol. Requires 'httparty' gem.
  # config.add_notifier :webhook, {
  #   :url => 'http://example.com:5555/hubot/path',
  #   :http_method => :post
  # }
end
