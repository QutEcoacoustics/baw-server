AWB::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { :host => "#{Settings.host.name}:#{Settings.host.port}" }

  config.action_mailer.delivery_method = :smtp

  config.action_mailer.smtp_settings = {
      :address        => Settings.smtp.address,
      :port           => Settings.smtp.port,
      :domain         => Settings.smtp.domain,
      :authentication => Settings.smtp.authentication,
      :user_name      => Settings.smtp.user_name,
      :password       => Settings.smtp.password
  }

  config.action_mailer.perform_deliveries = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  config.active_record.auto_explain_threshold_in_seconds = 0.5

  # Do not compress assets
  config.assets.compress = false

  # Expands the lines which load the assets
  config.assets.debug = true



  # Set path for image magick for windows only
  if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i
    im_dir = Settings.paths.image_magick_dir
    puts 'WARN: cannot find image magick path' unless File.directory? im_dir
    Paperclip.options[:command_path] = im_dir
  end

  AWB::Application.config.middleware.use ExceptionNotification::Rack,
  email: {
    email_prefix: Settings.exception_notification.email_prefix,
    sender_address:  Settings.exception_notification.sender_address,
    exception_recipients:  Settings.exception_notification.exception_recipients
  }

  config.after_initialize do
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.alert = true
    Bullet.rails_logger = true
    Bullet.add_footer = true
    Bullet.raise = false

    # rotate the log files once they reach 5MB and save the 3 most recent rotated logs
    config.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.log"), 3, 5.megabytes)
  end
end

