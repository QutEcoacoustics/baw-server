# Be sure to restart your server when you modify this file.
require 'rails/backtrace_cleaner'
# You can add backtrace silencers for libraries that you're using but don't wish to see in your backtraces.
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /my_noisy_library/ }

# You can also remove all the silencers if you're trying to debug a problem that might stem from framework code.
# Patch the standard silencer from https://github.com/rails/rails/blob/69ab3eb57e8387b0dd9d672b5e8d9185395baa03/railties/lib/rails/backtrace_cleaner.rb
# Otherwise it silences backtrace components in gems. This is especially bad for diagnosing errors inside our own gems!
Rails.backtrace_cleaner.remove_silencers!

# Rails.backtrace_cleaner.add_filter   { |line| line.gsub(Rails.root.to_s, '') } # strip the Rails.root prefix
# Rails.backtrace_cleaner.add_silencer { |line| line =~ /mongrel|rubygems/ } # skip any lines from mongrel or rubygems