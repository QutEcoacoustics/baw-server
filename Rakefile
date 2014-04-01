require 'bundler/gem_tasks'
require 'resque'
require 'resque/tasks'
require 'active_support/all'

task :run_worker, [:settings_file] do |t, args|
  args.with_defaults(settings_file: './lib/baw-workers/settings/settings.dev.yml')

  puts "===> Using settings file #{args.settings_file}"
  # set an env variable so the correct Settings class is used.
  ENV['BAW_WORKERS_ENV'] = 'RAKEFILE'
  # the require must be here to ensure the environment variable has been set.
  require './lib/baw-workers/settings'
  Settings.source(args.settings_file)

  queues = Settings.resque.queues_to_process.join(',')
  puts "===> Polling queues #{queues}."
  ENV['QUEUES'] = queues

  log_level = Settings.resque.log_level
  puts "===> Log level: #{log_level}."
  Resque.logger.level = log_level

  puts puts "===> Polling every #{Settings.resque.polling_interval_seconds} seconds."
  ENV['INTERVAL'] = Settings.resque.polling_interval_seconds.to_s

  unless Settings.resque.background_pid_file.blank?
    ENV['PIDFILE'] = Settings.resque.background_pid_file
    ENV['BACKGROUND'] = 'yes'
    $stdout.reopen(Settings.resque.output_log_file, 'w')
    $stdout.sync = true
    $stderr.reopen(Settings.resque.error_log_file, 'w')
    $stderr.sync = true
  end

  puts "===> Connecting to Redis on #{Settings.resque.connection}."
  Resque.redis = Settings.resque.connection

  # invoke the resque rake task
  Rake::Task['resque:work'].invoke
end
