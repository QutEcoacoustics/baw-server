# frozen_string_literal: true

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  #config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  # leave this enabled for the moment - we depend on rack rewrites in application.rb
  # to allow us to rewrite routes for the old angular app.
  # TODO: remove when old-client is deprecated!
  config.public_file_server.enabled = true
  config.serve_static_files = true

  # Compress JavaScripts and CSS.
  #config.assets.js_compressor = :uglifier
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # https://api.rubyonrails.org/classes/ActionDispatch/RemoteIp.html
  config.action_dispatch.trusted_proxies = BawApp.all_trusted_proxies

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  config.action_mailer.default_url_options =
    {
      host: Settings.host.name,
      protocol: BawApp.http_scheme
    }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = Settings.mailer.smtp.to_h
  config.action_mailer.deliver_later_queue_name = Settings.actions.active_job_default.queue

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # By default parameter keys that are not explicitly permitted will be logged in the development
  # and test environment. In other environments these parameters will simply be filtered out
  # and ignored. Additionally, this behaviour can be changed by changing the
  # config.action_controller.action_on_unpermitted_parameters property in your environment files.
  # If set to :log the unpermitted attributes will be logged, if set to :raise an exception will
  # be raised.
  # TODO: AT2020: Set this to `:raise` when old-client has been deprecated
  #config.action_controller.action_on_unpermitted_parameters = :raise

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
end
