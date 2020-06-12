ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

# important, we execute bundler.setup ourselves with an extra custom group.
# If we used `require 'bundler/setup'` then we would not get the opportunity to
# customize the group arguments!
require 'bundler'
# Set up gems listed in the Gemfile.
Bundler.setup(:default, :server)

require 'bootsnap/setup'