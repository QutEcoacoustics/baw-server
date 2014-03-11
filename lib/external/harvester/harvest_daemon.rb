require 'rubygems'
require 'daemons'

######################################################################################
# Runs the harvester in the background, without anyone logged in.
# ruby harvest_daemon.rb start -- '/absolute/path/to/default.yml'
# ruby harvest_daemon.rb stop -- '/absolute/path/to/default.yml'
# For debugging, use: (so it runs in console - can see what it's doing)
# ruby harvest_daemon.rb run -- '/absolute/path/to/default.yml'
######################################################################################

Daemons.run(File.join(File.dirname(__FILE__), 'harvest_listen.rb'), monitor: true)