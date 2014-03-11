require 'rubygems'
require 'daemons'

######################################################################################
# ruby daemonized_listener.rb start -- '/absolute/path/to/default.yml'
# ruby daemonized_listener.rb stop -- '/absolute/path/to/default.yml'
# For debugging, use: (so it runs in console - can see what it's doing)
# ruby daemonized_listener.rb run -- '/absolute/path/to/default.yml'
######################################################################################

Daemons.run(File.join(File.dirname(__FILE__), 'harvest_listen.rb'), monitor: true)