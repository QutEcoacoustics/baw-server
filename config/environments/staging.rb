AWB::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = true

  # Do not compress assets
  config.assets.compress = false

  # enable Rails to serve static assets -  this may be a performance issue
  # required to enable client to be reachable
  config.serve_static_assets = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)
  # keep 5 log files, max file size is 300 mb
  # http://www.ruby-doc.org/stdlib-1.9.3/libdoc/logger/rdoc/Logger.html#method-c-new
  # http://trevorturk.com/2010/10/14/limit-the-size-of-rails-3-log-files/
  #config.logger = Logger.new(config.paths.log.first, 5, 300.megabytes)

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )

  # Disable delivery errors, bad email addresses will be ignored
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { :host => "#{Settings.host.name}" }

  config.action_mailer.delivery_method = :sendmail
  config.action_mailer.perform_deliveries = true

  config.action_mailer.sendmail_settings = {
      :location       => '/usr/sbin/sendmail',
      :arguments      => '-i -t'
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
  # config.active_record.auto_explain_threshold_in_seconds = 0.5

  AWB::Application.config.middleware.use ExceptionNotification::Rack,
    email: {
      email_prefix: Settings.exception_notification.email_prefix,
      sender_address:  Settings.exception_notification.sender_address,
      exception_recipients:  Settings.exception_notification.exception_recipients
    }
end
