require File.dirname(__FILE__) + '/../harvester/harvester'
require File.dirname(__FILE__) + '/../../modules/exceptions'

require 'pathname'
require 'listen'
require 'daemons'


######################################################################################
# This is a command line tool that listens to the harvester_to_do directory for incoming
# folders containing a harvest.yml file. When harvest.yml is added or modified, it 
# processes that directory.
# Run this file like this:
# $ ruby listen_and_harvest.rb 'default.yml'
# $ ruby ./lib/external/harvester/listen_and_harvest.rb './lib/external/harvester/harvester_development.yml'
######################################################################################

class HarvestListener

  @yaml_config_file
  @listen_path

  def initialize(yaml_config_file)

    @yaml_config_file =  yaml_config_file
    yaml = YAML.load_file(@yaml_config_file)
    @listen_path = yaml['harvester_to_do_path'][0]
    # this sets the logger which is used in the harvester and shared Audio tools (audioffmpeg, audiosox, etc.)
    Logging::set_logger(Logger.new("#{@listen_path}/listen.log", 5, 300.megabytes))
    puts "Start listening to '#{@listen_path}'" if File.directory?(@listen_path)
  end

  def listen
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
        harvester = Harvester::Harvester.new(yaml_settings_file, dir)
        puts "Harvester Instantiated"
        harvester.start_harvesting
        puts "Finished Harvesting: '#{dir}"
      rescue Exceptions::HarvesterError => e
        # keep guard going even if harvester throws harvester error exception
        puts e
      rescue Exception => e
        puts e
      end
    end
  end

end


listener = HarvestListener.new(ARGV[0])
listener.listen