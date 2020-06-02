ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler' # Set up gems listed in the Gemfile.
Bundler.setup(:default, :server)

require 'bootsnap/setup'

require 'rails/commands/server'

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
