require 'trollop'
require File.dirname(__FILE__) + '/harvester'

########################################################
# Obsolete! But might come in handy in the future:
# This file allows harvesting multiple subdirectories
# within a harvester_to_do directory. Run it using:
# $ruby harvest_directory.rb -d path/to/harvester_to_do -y path/to/default.yml
########################################################

# command line arguments
opts = Trollop::options do
  opt :dir, 'Directory containing audio files and config file.', :type => :string
  opt :yaml_settings_file, 'Yaml settings file to load', :type => :string
end

Trollop::die :dir, 'directory must be given' if opts[:dir].nil?
Trollop::die :dir, 'must be a directory' if !File.directory?(opts[:dir])
Trollop::die :yaml_settings_file, 'must exist' unless File.exist?(opts[:yaml_settings_file]) if opts[:yaml_settings_file].nil?

# run the script for a directory
Dir.entries(opts[:dir]).each do |dir|
  if File.exists?(File.join(opts[:dir], dir, "harvest.yml"))
    puts "Started Harvesting #{dir}"
    harvester = Harvester::Harvester.new(opts[:yaml_settings_file], dir)
    harvester.start_harvesting
    puts "Finished Harvesting #{dir}"
  end
end

