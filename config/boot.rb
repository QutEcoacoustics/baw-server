require 'rubygems'

# add patch for userstamp here so it is loaded before the gem
# define Caboose::Acts::Paranoid so deleter_id is updated when a record is archived
module Caboose
  module Acts
    module Paranoid

    end
  end
end

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
