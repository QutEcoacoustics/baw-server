AWB::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # configure mailer for development
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options =
      {
          host: "#{Settings.host.name}:#{Settings.host.port}"
      }
  config.action_mailer.delivery_method = :file
  config.action_mailer.file_settings =
      {
          location: Rails.root.join('tmp', 'mail')
      }
  config.action_mailer.perform_deliveries = true

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
  config.assets.compress = true

  # Expands the lines which load the assets
  config.assets.debug = false

  # resque configuration
  Resque.redis = Settings.resque.connection

  # Set path for image magick for windows only
  if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i
    im_dir = Settings.paths.image_magick_dir
    if Dir.exists?(im_dir) && File.directory?(im_dir)
      Paperclip.options[:command_path] = im_dir
    else
      puts "WARN: cannot find image magick path #{im_dir}"
    end
  end

  AWB::Application.config.middleware.use ExceptionNotification::Rack, email:
      {
          email_prefix: Settings.emails.email_prefix,
          sender_address: Settings.emails.sender_address,
          exception_recipients: Settings.emails.required_recipients
      }

  config.log_level = :debug

  # profile requests
  #config.middleware.insert 0, 'Rack::RequestProfiler', printer: ::RubyProf::CallTreePrinter

  config.after_initialize do
    # detect n+1 queries
    Bullet.enable = true
    Bullet.bullet_logger = true
    Bullet.console = true
    Bullet.alert = true
    Bullet.rails_logger = true
    Bullet.add_footer = true
    Bullet.raise = false

    # By default, each log is created under Rails.root/log/ and the log file name is environment_name.log.
    config.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
    BawAudioTools::Logging.logger_formatter(config.logger)

    config.action_mailer.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.mailer.log"))
    BawAudioTools::Logging.logger_formatter(config.action_mailer.logger)

    # log all activerecord activity
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end
end

