require File.expand_path('boot', __dir__)

require 'English'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.setup(*Rails.groups, :default, :server)
Bundler.require(*Rails.groups, :server)

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

    config.load_defaults '6.0'

    # we should never need to to autoload anything in ./app
    config.add_autoload_paths_to_load_path = false

    #Rails.autoloaders.log! # debug only!

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
    config.time_zone = 'UTC'

    # config.active_record.default_timezone determines whether to use Time.local (if set to :local)
    # or Time.utc (if set to :utc) when pulling dates and times from the database.
    # The default is :utc.
    #config.active_record.default_timezone = :utc

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en]

    # specify the class to handle exceptions
    config.exceptions_app = lambda { |env|
      ErrorsController.action(:uncaught_error).call(env)
    }

    Rails::Html::SafeListSanitizer.allowed_tags.merge(['table', 'tr', 'td', 'caption', 'thead', 'th', 'tfoot', 'tbody', 'colgroup'])

    # middleware to rewrite angular urls
    # insert at the start of the Rack stack.
    config.middleware.insert_before 0, Rack::Rewrite do
      # angular routing system will use the url that was originally requested
      # rails just needs to load the index.html

      # ensure you add url helpers in app/helpers/application_helper.rb

      rewrite(%r{^/listen.*}i, '/listen_to/index.html')
      rewrite(%r{^/birdwalks.*}i, '/listen_to/index.html')
      rewrite(%r{^/library.*}i, '/listen_to/index.html')
      rewrite(%r{^/demo.*}i, '/listen_to/index.html')
      rewrite(%r{^/visualize.*}i, '/listen_to/index.html')
      rewrite(%r{^/audio_analysis.*}i, '/listen_to/index.html')
      rewrite(%r{^/citsci.*}i, '/listen_to/index.html')
    end

    # Sanity check: test dependencies should not be loadable
    unless Rails.env.test?
      def module_exists?(name, base = self.class)
        base.const_defined?(name) && base.const_get(name).instance_of?(::Module)
      end

      test_deps = ['RSpec::Core::DSL', 'RSpec::Core::Version']
      first_successful_require = test_deps.find { |x| module_exists?(x) }
      if first_successful_require
        throw "Test dependencies available in non-test environment. `#{first_successful_require}` should not be a constant`"
      end
    end
  end
end
