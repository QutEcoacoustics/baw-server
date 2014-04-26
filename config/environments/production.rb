AWB::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # No longer correct: Disable Rails's static asset server (Apache or nginx will already do this)
  # enable Rails to serve static assets -  this may be a performance issue
  # required to enable client to be reachable
  config.serve_static_assets = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.perform_deliveries = true

  config.action_mailer.default_url_options =
      {
          host: "#{Settings.host.name}"
      }

  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings =
      {
          address: Settings.smtp.address
      }

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  AWB::Application.config.middleware.use ExceptionNotification::Rack, email:
      {
          email_prefix: Settings.exception_notification.email_prefix,
          sender_address: Settings.exception_notification.sender_address,
          exception_recipients: Settings.exception_notification.exception_recipients
      }

  config.after_initialize do
    # By default, each log is created under Rails.root/log/ and the log file name is environment_name.log.
    config.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
    BawAudioTools::Logging.logger_formatter(config.logger)

    config.action_mailer.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.mailer.log"))
    BawAudioTools::Logging.logger_formatter(config.action_mailer.logger)

    # See everything in the log (default is :info)
    # config.log_level = :debug

    # Prepend all log lines with the following tags
    # config.log_tags = [ :subdomain, :uuid ]
  end
end
