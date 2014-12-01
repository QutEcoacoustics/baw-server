require File.expand_path('../boot', __FILE__)

require 'rails/all'

# some patches need to be applied before gems load
require "#{File.dirname(__FILE__)}/../lib/patches/random"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AWB
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib/validators)
    # add all dirs recursively from lib/modules
    config.autoload_paths += Dir["#{config.root}/lib/modules/**/"]

    # Custom setup
    # enable garbage collection profiling (reported in New Relic)
    GC::Profiler.enable

    require "#{File.dirname(__FILE__)}/../app/models/settings"

    # validate server Settings file
    Settings.validate

    # resque setup
    Resque.redis = Settings.resque.connection
    Resque.redis.namespace = Settings.resque.namespace

    # logging
    # By default, each log is created under Rails.root/log/ and the log file name is <component_name>.<environment_name>.log.

    # The default Rails log level is warn in production env and info in any other env.
    current_log_level = Rails.env.production? ? Logger::WARN : Logger::INFO

    rails_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "rails.#{Rails.env}.log")))
    rails_logger.level = current_log_level

    mailer_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.mailer_log_file))
    mailer_logger.level = Logger.const_get(Settings.mailer.log_level)

    active_record_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "activerecord.#{Rails.env}.log")))
    active_record_logger.level = current_log_level

    resque_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.worker_log_file))
    resque_logger.level = Logger.const_get(Settings.resque.log_level)

    audio_tools_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.audio_tools_log_file))
    audio_tools_logger.level = Logger.const_get(Settings.audio_tools.log_level)

    # core rails logging
    config.logger = rails_logger

    # action mailer logging
    config.action_mailer.logger = mailer_logger
    BawWorkers::Config.logger_mailer = mailer_logger

    # activerecord logging
    ActiveRecord::Base.logger =active_record_logger

    # resque logging
    Resque.logger = resque_logger
    BawWorkers::Config.logger_worker = resque_logger

    # audio tools logging
    BawWorkers::Config.logger_audio_tools = audio_tools_logger

    # BawWorkers setup
    BawWorkers::Config.run_web(rails_logger, mailer_logger, resque_logger, audio_tools_logger, Settings, Rails.env.test? || Rails.env.development?)

    # end custom setup

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # check that locales are valid - new default in rails 3.2.14
    config.i18n.enforce_available_locales = true

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Raise exception on mass assignment protection for Active Record models
    config.active_record.mass_assignment_sanitizer = :strict

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    #config.time_zone - 'UTC'
    config.time_zone = 'Brisbane'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.default_locale = 'en-AU'
    config.i18n.fallbacks = {'en-AU' => 'en'}

    # specify the class to handle exceptions
    config.exceptions_app = ->(env) {
      ErrorsController.action(:uncaught_error).call(env)
    }

    # set paperclip default path and url
    Paperclip::Attachment.default_options[:path] = ':rails_root/public:url'
    Paperclip::Attachment.default_options[:url] = '/system/:class/:attachment/:id_partition/:style/:filename'

    # for generating documentation from tests
    Raddocs.configuration.docs_dir = "doc/api"

    # allow any origin, with any header, to access the array of methods
    config.middleware.use Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :delete, :options]
      end
    end

    # middleware to rewrite angular urls
    # insert at the start of the Rack stack.
    config.middleware.insert_before(0, Rack::Rewrite) do
      # angular routing system will use the url that was originally requested
      # rails just needs to load the index.html
      rewrite /^\/listen.*/i, '/system/listen_to/index.html'
      rewrite /^\/birdwalks.*/i, '/system/listen_to/index.html'
      rewrite /^\/library.*/i, '/system/listen_to/index.html'
    end

  end
end
