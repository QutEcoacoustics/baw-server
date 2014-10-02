require File.expand_path('../boot', __FILE__)

require 'rails/all'

# some patches need to be applied before gems load
require "#{File.dirname(__FILE__)}/../lib/patches/enable_stampable_deleter"
require "#{File.dirname(__FILE__)}/../lib/patches/big_decimal"
require "#{File.dirname(__FILE__)}/../lib/patches/float"
require "#{File.dirname(__FILE__)}/../lib/patches/random"

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development staging test)))
  # If you want your assets lazily compiled in production, use this line
  Bundler.require(:default, :assets, Rails.env)
end

module AWB
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/lib/validators)
    # add all dirs recursively from lib/modules
    config.autoload_paths += Dir["#{config.root}/lib/modules/**/"]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # check that locales are valid - new default in rails 3.2.14
    config.i18n.enforce_available_locales = true

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    #config.time_zone - 'UTC'
    config.time_zone = 'Brisbane'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.default_locale = 'en-AU'
    config.i18n.fallbacks = {'en-AU' => 'en'}

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    config.active_record.whitelist_attributes = true

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

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

    config.after_initialize do
      # validate Settings file
      Settings.validate

      # set resque connection
      Resque.redis = Settings.resque.connection

      # set resque namespace
      Resque.redis.namespace = Settings.resque.namespace

      # enable garbage collection profiling (reported in New Relic)
      GC::Profiler.enable

      # logging
      # By default, each log is created under Rails.root/log/ and the log file name is environment_name.log.
      # The default Rails log level is info in production env and debug in any other env.

      current_log_level = Rails.env.production? ? Logger::INFO : Logger::DEBUG
      log_rotation_frequency = 'weekly'

      # core rails logging
      config.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.log"), log_rotation_frequency)
      config.logger.formatter = BawAudioTools::CustomFormatter.new
      config.logger.level = current_log_level

      # action mailer logging
      config.action_mailer.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.mailer.log"), log_rotation_frequency)
      config.action_mailer.logger.formatter = BawAudioTools::CustomFormatter.new
      config.action_mailer.logger.level = current_log_level

      # activerecord logging
      ActiveRecord::Base.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.activerecord.log"), log_rotation_frequency)
      ActiveRecord::Base.logger.formatter = BawAudioTools::CustomFormatter.new
      ActiveRecord::Base.logger.level = current_log_level

      # resque logging
      Resque.logger = Logger.new(Rails.root.join('log', "#{Rails.env}.resque.log"), log_rotation_frequency)
      Resque.logger.formatter = BawAudioTools::CustomFormatter.new
      Resque.logger.level = current_log_level

      # audio tools logging
      BawAudioTools::Logging.set_logger(Logger.new(Rails.root.join('log', "#{Rails.env}.audiotools.log"), log_rotation_frequency))
      BawAudioTools::Logging.set_level(current_log_level)
    end

  end
end
