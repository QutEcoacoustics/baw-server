require 'rake'
require 'resque/tasks'

namespace :baw_workers do

  # Set up the worker parameters. Takes one argument: settings_file
  desc 'Run setup for Resque worker'
  task :setup_worker, [:settings_file] do |t, args|
    args.with_defaults(settings_file: File.join(File.dirname(__FILE__), '..', 'settings.default.yml'))

    BawWorkers::Settings.set_source(args.settings_file)
    BawWorkers::Settings.set_namespace('settings')

    if BawWorkers::Settings.resque.background_pid_file.blank?
      puts '===> Running in foreground.'
    else
      STDOUT.reopen(File.open(BawWorkers::Settings.resque.output_log_file, 'a+'))
      STDOUT.sync = true
      STDERR.reopen(File.open(BawWorkers::Settings.resque.error_log_file, 'a+'))
      STDERR.sync = true

      puts "===> Running in background with pid file #{BawWorkers::Settings.resque.background_pid_file}."
      ENV['PIDFILE'] = BawWorkers::Settings.resque.background_pid_file
      ENV['BACKGROUND'] = 'yes'
    end

    queues = BawWorkers::Settings.resque.queues_to_process.join(',')
    puts "===> Polling queues #{queues}."
    ENV['QUEUES'] = queues

    log_level = BawWorkers::Settings.resque.log_level
    puts "===> Log level: #{log_level}."
    Resque.logger.level = log_level
    ENV['VERBOSE '] = '1'
    ENV['VVERBOSE '] = '1'

    puts "===> Polling every #{BawWorkers::Settings.resque.polling_interval_seconds} seconds."
    ENV['INTERVAL'] = BawWorkers::Settings.resque.polling_interval_seconds.to_s

    # use new signal handling
    # http://hone.heroku.com/resque/2012/08/21/resque-signals.html
    #ENV['TERM_CHILD'] = '1'
  end

  # run a worker. Passes parameter to prerequisite 'setup_worker'. Takes one argument: settings_file
  # examples:
  # bundle exec rake baw_workers:run_worker
  # bundle exec rake baw_workers:run_worker['/home/ubuntu/bioacoustics/workers/settings.media.yml']
  desc 'Run a resque:work with the specified settings file.'
  task :run_worker, [:settings_file] => [:setup_worker] do |t, args|

    puts "===> Connecting to Redis on #{BawWorkers::Settings.resque.connection}."
    Resque.redis = BawWorkers::Settings.resque.connection
    #Resque.redis = Redis.new

    # invoke the resque rake task
    Rake::Task['resque:work'].invoke
  end
end