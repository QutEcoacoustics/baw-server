# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('config/application', __dir__)

require 'github_changelog_generator/task'

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'QutEcoacoustics'
  config.project = 'baw-server'
  config.since_tag = '2.0.1'
  config.future_release = ENV['NEXT_VERSION']
end

Rails.application.load_tasks
