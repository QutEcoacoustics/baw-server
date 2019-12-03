ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler' # Set up gems listed in the Gemfile.
Bundler.setup(:default, :server)

require 'bootsnap/setup'
