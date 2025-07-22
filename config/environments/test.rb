# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    'Cache-Control' => 'public, max-age=3600'
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = :none

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false
  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.raise_delivery_errors = true

  config.action_mailer.default_url_options =
    {
      host: Settings.host.name,
      port: Settings.host.port,
      protocol: BawApp.http_scheme
    }

  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true
  config.action_mailer.deliver_later_queue_name = Settings.actions.active_job_default.queue

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # By default parameter keys that are not explicitly permitted will be logged in the development
  # and test environment. In other environments these parameters will simply be filtered out
  # and ignored. Additionally, this behaviour can be changed by changing the
  # config.action_controller.action_on_unpermitted_parameters property in your environment files.
  # If set to :log the unpermitted attributes will be logged, if set to :raise an exception will
  # be raised.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Raises error for missing translations
  config.i18n.raise_on_missing_translations = true

  # Paperclip default location in tmp, so it can be cleared after test suite is run
  Paperclip::Attachment.default_options[:path] = ':rails_root/tmp/paperclip:url'

  config.after_initialize do
    # detect n+1 queries
    Bullet.enable = true
    Bullet.bullet_logger = true
    # Bullet.console = true
    # Bullet.alert = false
    # Bullet.console = true
    # Bullet.rails_logger = true
    Bullet.raise = true
    # this is vendor code, we don't control it, not our fault
    Bullet.add_safelist type: :unused_eager_loading, class_name: 'ActiveStorage::Attachment', association: :record
  end
  # config.i18n.raise_on_missing_translations = true
end
