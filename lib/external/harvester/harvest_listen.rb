require 'pathname'
require 'listen'
require 'daemons'

require File.dirname(__FILE__) + '/../harvester/harvest_manager'
require File.dirname(__FILE__) + '/../../modules/exceptions'

######################################################################################
# Run the harvester on a polling loop so it can process changes as they happen.
# This is a command line tool that listens to the harvester_to_do directory for incoming
# folders containing a harvest.yml file. When harvest.yml is added or modified, it 
# processes that directory.
# Run this file like this:
# $ ruby harvest_listen.rb 'default.yml'
# $ ruby ./lib/external/harvester/harvest_listen.rb './lib/external/harvester/harvester_development.yml'
######################################################################################
module Harvester
  class Listener

    attr_reader :harvest_manager

    def initialize(global_config_file)
      @harvest_manager = Harvester::Manager.new(global_config_file)
    end

    def listen
      harvester_to_do = @harvest_manager.harvester_to_do
      if File.directory?(harvester_to_do)
        puts "Start listening to '#{@listen_path}'"
      else
        raise Exceptions::HarvesterConfigurationError, "Could not find harvester_to_do path: #{harvester_to_do}"
      end

      Listen.to!(@listen_path, filter: %r{harvest.yml$}, relative_paths: false) do |modified, added, removed|

        puts "Modified: #{modified}"
        puts "Added: #{added}"
        puts "Removed: #{removed}"

        @harvest_manager.harvest_directories(added.concat(modified))
      end
    end
  end
end

listener = Harvester::Listener.new(ARGV[0])
listener.listen