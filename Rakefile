# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)

begin
  require 'github_changelog_generator/task'

  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.user = 'QutEcoacoustics'
    config.project = 'baw-server'
    config.since_tag = '2.0.1'
    config.future_release = ENV['NEXT_VERSION']
  end
rescue LoadError
  # allow other environments to fail loading... this set of tasks is only
  # intended to run in a development environment!
  raise if Rails.development?
end

Rails.application.load_tasks
