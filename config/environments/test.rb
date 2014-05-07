AWB::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options =
      {
          host: "#{Settings.host.name}:#{Settings.host.port}"
      }
  config.action_mailer.delivery_method = :test
  config.action_mailer.perform_deliveries = true

  # Raise exception on mass assignment protection for Active Record models
  config.active_record.mass_assignment_sanitizer = :strict

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # Paperclip default location in tmp, so it can be cleared after test suite is run
  Paperclip::Attachment.default_options[:path] = ':rails_root/tmp/paperclip:url'

  # Set path for image magick for windows only
  if RbConfig::CONFIG['target_os'] =~ /mswin|mingw/i
    im_dir = Settings.paths.image_magick_dir
    if Dir.exists?(im_dir) && File.directory?(im_dir)
      Paperclip.options[:command_path] = im_dir
    else
      puts "WARN: cannot find image magick path #{im_dir}"
    end
  end

  config.log_level = :info

  config.after_initialize do
    # detect n+1 queries
    Bullet.enable = false
    Bullet.bullet_logger = false
    Bullet.console = false
    Bullet.alert = false
    Bullet.rails_logger = false
    Bullet.add_footer = false
    Bullet.raise = false

    config.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
    BawAudioTools::Logging.logger_formatter(config.logger)

    config.action_mailer.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.mailer.log"))
    BawAudioTools::Logging.logger_formatter(config.action_mailer.logger)

    # log all activerecord activity
    ActiveRecord::Base.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.activerecord.log"))
    config.active_record.colorize_logging = false
    BawAudioTools::Logging.logger_formatter(ActiveRecord::Base.logger)
  end

end

