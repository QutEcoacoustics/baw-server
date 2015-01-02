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

    # Currently, Active Record suppresses errors raised within `after_rollback`/`after_commit`
    # callbacks and only print them to the logs. In the next version, these errors will no
    # longer be suppressed. Instead, the errors will propagate normally just like in other
    # Active Record callbacks.
    config.active_record.raise_in_transactional_callbacks = true

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

    # specify the class to handle exceptions
    config.exceptions_app = ->(env) {
      ErrorsController.action(:uncaught_error).call(env)
    }

    # set paperclip default path and url
    Paperclip::Attachment.default_options[:path] = ':rails_root/public:url'
    Paperclip::Attachment.default_options[:url] = '/system/:class/:attachment/:id_partition/:style/:filename'

    # for generating documentation from tests
    Raddocs.configuration.docs_dir = "doc/api"

    # middleware to rewrite angular urls
    # insert at the start of the Rack stack.
    config.middleware.insert_before 0, Rack::Rewrite do
      # angular routing system will use the url that was originally requested
      # rails just needs to load the index.html
      rewrite /^\/listen.*/i, '/system/listen_to/index.html'
      rewrite /^\/birdwalks.*/i, '/system/listen_to/index.html'
      rewrite /^\/library.*/i, '/system/listen_to/index.html'
      rewrite /^\/demo.*/i, '/system/listen_to/index.html'
    end

    # allow any origin, with any header, to access the array of methods
    # insert as first middleware, after other changes.
    # this ensures static files, caching, and auth will include CORS headers
    config.middleware.insert_before 0, 'Rack::Cors', debug: true, logger: (-> { Rails.logger }) do
      allow do

        # 'Access-Control-Allow-Origin' (origins):
        origins Settings.host.cors_origins

        # 'Access-Control-Max-Age' (max_age): "indicates how long the results of a preflight request can be cached"
        # -> not specifying to avoid debugging problems

        # 'Access-Control-Allow-Credentials' (credentials): "Indicates whether or not the response to the request
        # can be exposed when the credentials flag is true.  When used as part of a response to a preflight request,
        # this indicates whether or not the actual request can be made using credentials.  Note that simple GET
        # requests are not preflighted, and so if a request is made for a resource with credentials, if this header
        # is not returned with the resource, the response is ignored by the browser and not returned to web content."
        # -> specifying true to enable authentication on preflight and actual requests.

        # 'Access-Control-Allow-Methods' (methods): "Specifies the method or methods allowed when accessing the
        # resource.  This is used in response to a preflight request."
        # -> including patch, head, options in addition to usual suspects

        # 'Access-Control-Allow-Headers' (headers): "Used in response to a preflight request to indicate which HTTP
        # headers can be used when making the actual request."
        # -> allow any header to be sent by client

        # 'Access-Control-Expose-Headers' (expose): "lets a server whitelist headers that browsers are allowed to access"
        # auto-allowed headers: Cache-Control, Content-Language, Content-Type, Expires, Last-Modified, Pragma
        # http://www.w3.org/TR/cors/#simple-response-header
        # -> we have some custom headers that we want to access, plus content-length
        # -> TODO: this will need to be updated when generating and waiting time are separated to two headers rather than one

        resource '*', # applies to all resources
                 headers: :any,
                 methods: [:get, :post, :put, :patch, :head, :delete, :options],
                 credentials: true,
                 expose: MediaPoll::HEADERS_EXPOSED


      end
    end

  end
end
