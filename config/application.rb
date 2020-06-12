require File.expand_path('../boot', __FILE__)

require 'English'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.setup(*Rails.groups, :default, :server)
Bundler.require(*Rails.groups, :server)

require 'rails/commands/server/server_command.rb'
# bind to 0.0.0.0 by default when running rails server
# - useful when running inside a container
module Rails
  class Server
    alias :default_options_backup :default_options
    def default_options
      default_options_backup.merge!(Host: '0.0.0.0')
    end
  end
end

# require things that aren't gems but are gem-like
# Why do this and not rely on autoload magic? Because magic. I find it is simpler
# to debug things that have less magic and a clear, transparent invocation
require "#{__dir__}/../lib/gems/baw-app/lib/baw_app"
require "#{__dir__}/../lib/gems/baw-audio-tools/lib/baw_audio_tools"
require "#{__dir__}/../lib/gems/baw-workers/lib/baw_workers"

module AWB
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    config.before_initialize do
      require "#{__dir__}/settings"
    end

    config.load_defaults '6.0'

    # we should never need to to autoload anything in ./app
    config.add_autoload_paths_to_load_path = false

    Rails.autoloaders.log! # debug only!

    # add patches
    # zeitwerk specifically does not deal with the concept if overrides,
    # so patches need to be required manually
    Dir.glob(config.root.join('lib', 'patches', '**/*.rb')).sort.each do |override|
      #puts "loading #{override}"
      require override
    end

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # schema format - set to sql to support case-insensitive indexes and other things
    config.active_record.schema_format = :sql

    # check that locales are valid - new default in rails 3.2.14
    config.i18n.enforce_available_locales = true

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


    Rails::Html::SafeListSanitizer.allowed_tags.merge(['table', 'tr', 'td', 'caption', 'thead', 'th', 'tfoot', 'tbody', 'colgroup'])

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
    config.middleware.insert_before 0, Rack::Cors, debug: true, logger: (-> { Rails.logger }) do
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
