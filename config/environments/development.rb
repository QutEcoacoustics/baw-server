# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # configure mailer for development.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options =
    {
      host: Settings.host.name,
      protocol: BawApp.http_scheme,
      port: Settings.host.port
    }
  config.action_mailer.delivery_method = :file
  config.action_mailer.file_settings =
    {
      location: Rails.root.join('tmp/mail')
    }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.deliver_later_queue_name = Settings.actions.active_job_default.queue

  # enable colorized logs
  config.colorized_logging = true

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html
  config.action_dispatch.trusted_proxies = BawApp.all_trusted_proxies

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # By default parameter keys that are not explicitly permitted will be logged in the development
  # and test environment. In other environments these parameters will simply be filtered out
  # and ignored. Additionally, this behaviour can be changed by changing the
  # config.action_controller.action_on_unpermitted_parameters property in your environment files.
  # If set to :log the unpermitted attributes will be logged, if set to :raise an exception will
  # be raised.
  config.action_controller.action_on_unpermitted_parameters = :raise

  # Raises error for missing translations
  config.i18n.raise_on_missing_translations = true

  # profile requests
  #config.middleware.insert 0, Rack::RequestProfiler, printer: ::RubyProf::CallTreePrinter

  config.after_initialize do
    # empty
  end

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
