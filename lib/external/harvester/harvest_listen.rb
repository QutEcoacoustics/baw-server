require 'pathname'
require 'listen'
require 'daemons'

require File.dirname(__FILE__) + '/../harvester/harvest_manager'
require File.dirname(__FILE__) + '/../../modules/exceptions'

######################################################################################
# This is a command line tool that listens to the harvester_to_do directory for incoming
# folders containing a harvest.yml file. When harvest.yml is added or modified, it 
# processes that directory.
# Run this file like this:
# $ ruby harvest_listen.rb 'default.yml'
# $ ruby ./lib/external/harvester/harvest_listen.rb './lib/external/harvester/harvester_development.yml'
######################################################################################

class HarvestListener

  attr_reader :listen_path

  def initialize(listen_path, )
    # this sets the logger which is used in the harvester and shared Audio tools (audioffmpeg, audiosox, etc.)
    Logging::set_logger(Logger.new("#@listen_path/listen.log"))
  end

  def listen
    puts "Start listening to '#{@listen_path}'" if File.directory?(@listen_path)
    Listen.to!(@listen_path, filter: %r{harvest.yml$}, relative_paths: true) do |modified, added, removed|
      puts "Modified: #{modified}"
      puts "Added: #{added}"
      puts "Removed: #{removed}"
      added.each do |harvest_file|
        harvest(harvest_file, @yaml_config_file)
      end

      modified.each do |harvest_file|
        harvest(harvest_file, @yaml_config_file)
      end
    end
  end

  def harvest(harvest_file, yaml_settings_file)
    harvest_file_full_path = File.join(@listen_path, harvest_file)
    dir = File.dirname(harvest_file_full_path)
    puts "Processing: #{harvest_file_full_path} in #{dir}"
    if File.exists?(harvest_file_full_path)
      begin
        puts "Started Harvesting: '#{dir}' with #{yaml_settings_file}"
        harvester = Harvester::Manager.new(yaml_settings_file, dir)
        puts 'Harvester Instantiated'
        harvester.start_harvesting
        puts "Finished Harvesting: '#{dir}"
      #rescue Exceptions::HarvesterError => e
      #  # keep guard going even if harvester throws harvester error exception
      #  puts e.inspect
      #rescue Exception => e
      #  puts e.inspect
      end
    end
  end

end


listener = HarvestListener.new(ARGV[0])
listener.listen