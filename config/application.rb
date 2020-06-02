require File.expand_path('../boot', __FILE__)

require 'English'
require 'rails/all'

# some patches need to be applied before gems load
require "#{File.dirname(__FILE__)}/../lib/patches/random"
#require "#{File.dirname(__FILE__)}/../lib/patches/big_decimal"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.setup(*Rails.groups, :default, :server)
Bundler.require(*Rails.groups, :server)

module AWB
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # TODO: remove when upgrading to rails 6
    require 'zeitwerk'
    loader = Zeitwerk::Loader.new
    loader.tag = 'rails'

    loader.ignore(config.root.join('lib', 'tasks'))

    loader.push_dir(config.root.join('lib', 'validators'))
    loader.push_dir(config.root.join('lib', 'gems'))
    loader.push_dir(config.root.join('lib', 'modules'))

    loader.tag = 'rails'
    #loader.log! # debug only!
    loader.setup
    # TODO: but add this back in
    #config.autoload_paths << config.root.join('lib')

    # add patches
    # zeitwerk specifically avoids double loading modules, so patches need to be
    # required manually
    #config.autoload_paths << config.root.join('lib', 'patches','mime_type.rb')
    require config.root.join('lib', 'patches', 'mime', 'type.rb')

    #config.autoload_paths << config.root.join('lib', 'patches','paperclip_content_matcher.rb')
    #config.autoload_paths << config.root.join('lib', 'patches','rspec_api_documentation.rb')

    # Custom setup
    # enable garbage collection profiling (reported in New Relic, which we no longer use)
    #GC::Profiler.enable

    require "#{File.dirname(__FILE__)}/settings"

    Settings.validate

    # resque setup
    Resque.redis = HashWithIndifferentAccess.new(Settings.resque.connection)
    Resque.redis.namespace = Settings.resque.namespace

    # logging
    # By default, each log is created under Rails.root/log/ and the log file name is <component_name>.<environment_name>.log.

    # The default Rails log level is warn in production env and info in any other env.
    current_log_level = Logger::DEBUG
    current_log_level = Logger::INFO if Rails.env.staging?
    current_log_level = Logger::WARN if Rails.env.production?

    rails_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "rails.#{Rails.env}.log")))
    rails_logger.attach(Logger.new(STDOUT)) if Rails.env.development?
    rails_logger.level = current_log_level

    mailer_logger = BawWorkers::MultiLogger.new(Logger.new(Settings.paths.mailer_log_file))
    mailer_logger.level = Logger.const_get(Settings.mailer.log_level)

    active_record_logger = BawWorkers::MultiLogger.new(Logger.new(Rails.root.join('log', "activerecord.#{Rails.env}.log")))
    active_record_logger.attach(Logger.new(STDOUT)) if Rails.env.development?
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
    ActiveRecord::Base.logger = active_record_logger

    # resque logging
    Resque.logger = resque_logger
    BawWorkers::Config.logger_worker = resque_logger

    # audio tools logging
    BawWorkers::Config.logger_audio_tools = audio_tools_logger

    # BawWorkers setup
    BawWorkers::Config.run_web(rails_logger, mailer_logger, resque_logger, audio_tools_logger, Settings)

    # end custom setup

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # schema format - set to sql to support case-insensitive indexes and other things
    config.active_record.schema_format = :sql

    # Currently, Active Record suppresses errors raised within `after_rollback`/`after_commit`
    # callbacks and only print them to the logs. In the next version, these errors will no
    # longer be suppressed. Instead, the errors will propagate normally just like in other
    # Active Record callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # check that locales are valid - new default in rails 3.2.14
    config.i18n.enforce_available_locales = true

    # this is only respected by the activesupport-json_encoder gem.
    ActiveSupport.encode_big_decimal_as_string = false

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'
    #config.time_zone - 'UTC'
    config.time_zone = 'Brisbane'

    # config.active_record.default_timezone determines whether to use Time.local (if set to :local)
    # or Time.utc (if set to :utc) when pulling dates and times from the database.
    # The default is :utc.
    #config.active_record.default_timezone = :utc

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en]

    # specify the class to handle exceptions
    config.exceptions_app = ->(env) {
      ErrorsController.action(:uncaught_error).call(env)
    }

    # set paperclip default path and url
    Paperclip::Attachment.default_options[:path] = ':rails_root/public:url'
    Paperclip::Attachment.default_options[:url] = '/system/:class/:attachment/:id_partition/:style/:filename'

    ActionView::Base.sanitized_allowed_tags.merge(['table', 'tr', 'td', 'caption', 'thead', 'th', 'tfoot', 'tbody', 'colgroup'])

    # middleware to rewrite angular urls
    # insert at the start of the Rack stack.
    config.middleware.insert_before 0, Rack::Rewrite do
      # angular routing system will use the url that was originally requested
      # rails just needs to load the index.html

      # ensure you add url helpers in app/helpers/application_helper.rb

      rewrite /^\/listen.*/i, '/listen_to/index.html'
      rewrite /^\/birdwalks.*/i, '/listen_to/index.html'
      rewrite /^\/library.*/i, '/listen_to/index.html'
      rewrite /^\/demo.*/i, '/listen_to/index.html'
      rewrite /^\/visualize.*/i, '/listen_to/index.html'
      rewrite /^\/audio_analysis.*/i, '/listen_to/index.html'
      rewrite /^\/citsci.*/i, '/listen_to/index.html'
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

        resource '*', # applies to all resources
                 headers: :any,
                 methods: [:get, :post, :put, :patch, :head, :delete, :options],
                 credentials: true,
                 expose: MediaPoll::HEADERS_EXPOSED + %w(X-Archived-At X-Error-Type)
      end
    end

    # Sanity check: test dependencies should not be loadable
    unless Rails.env.test?
      def module_exists?(name, base = self.class)
        base.const_defined?(name) && base.const_get(name).instance_of?(::Module)
      end

      test_deps = [ 'RSpec::Core::DSL', 'RSpec::Core::Version' ]
      first_successful_require = test_deps.find { |x| module_exists?(x) }
      if first_successful_require
        throw "Test dependencies available in non-test environment. `#{first_successful_require}` should not be a constant`"
      end
    end
  end
end
