require 'rake'
require 'resque/tasks'

# mirror baw-workers gem startup
require 'active_support/all'
require 'logger'
require 'net/http'
require 'pathname'

require 'baw-audio-tools'

require 'resque'
require 'resque_solo'
require 'resque-job-stats'

require 'baw-workers/version'
require 'baw-workers/settings'
require 'baw-workers/common'
require 'baw-workers/mail/mailer'

require 'baw-workers/register_mime_types'

# set time zone
Time.zone = 'UTC'

namespace :baw_workers do

  desc 'Load settings and connect to Redis'
  task :init_worker, [:settings_file] do |t, args|
    args.with_defaults(settings_file: File.join(File.dirname(__FILE__), '..', 'settings.default.yml'))

    BawWorkers::Settings.set_source(args.settings_file)
    BawWorkers::Settings.set_namespace('settings')

    # define the Settings class for baw-audio-tools
    unless defined? Settings
      class Settings < BawWorkers::Settings
        source BawWorkers::Settings.source
        namespace 'settings'
      end
    end

    puts "===> Connecting to Redis on #{BawWorkers::Settings.resque.connection}."
    Resque.redis = BawWorkers::Settings.resque.connection
    Resque.redis.namespace = Settings.resque.namespace
  end

  # Set up the worker parameters. Takes one argument: settings_file
  desc 'Run setup for Resque worker'
  task :setup_worker, [:settings_file] => [:init_worker] do |t, args|

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
    log_file = Settings.resque.output_log_file
    puts "===> Logging to #{log_file} at level #{log_level}."
    Resque.logger = Logger.new(log_file)
    BawAudioTools::Logging.logger_formatter(Resque.logger)
    Resque.logger.level = log_level

    # set resque verbose on
    ENV['VERBOSE '] = '1'
    ENV['VVERBOSE '] = '1'

    puts "===> Polling every #{BawWorkers::Settings.resque.polling_interval_seconds} seconds."
    ENV['INTERVAL'] = BawWorkers::Settings.resque.polling_interval_seconds.to_s

    # use new signal handling
    # http://hone.heroku.com/resque/2012/08/21/resque-signals.html
    #ENV['TERM_CHILD'] = '1'
  end

  # run a worker. Passes parameter to prerequisite 'setup_worker'. Takes one argument: settings_file
  # start examples:
  # bundle exec rake baw_workers:run_worker
  # bundle exec rake baw_workers:run_worker['/home/user/folder/workers/settings.media.yml']
  # stopping workers:
  # kill -s QUIT $(/home/user/folder/workers/media.pid)
  desc 'Run a resque:work with the specified settings file.'
  task :run_worker, [:settings_file] => [:setup_worker] do |t, args|

    # invoke the resque rake task
    Rake::Task['resque:work'].invoke
  end

  desc 'Quit running workers'
  task :stop_workers, [:settings_file] => [:init_worker] do |t, args|

    pids = Array.new
    Resque.workers.each do |worker|
      pids.concat(worker.worker_pids)
      host, pid, queues_raw = worker.to_s.split(':')
      puts "Worker with host: #{host}, queues: #{worker.queues.join(', ')}"
    end
    if pids.empty?
      puts 'No workers to kill'
    else

      syscmd = "kill -s QUIT #{pids.join(' ')}"
      puts "Running syscmd to kill all workers: #{syscmd}"
      system(syscmd)
    end
  end

  desc 'List running workers'
  task :current_workers, [:settings_file] => [:init_worker] do |t, args|
    workers = Resque.workers
    if !workers.blank? && workers.size > 0
      puts "Current workers (#{workers.size}):"
      workers.each do |worker|
        host, pid, queues_raw = worker.to_s.split(':')
        puts "Worker with host: #{host}, queues: #{worker.queues.join(', ')}"
      end
    else
      puts 'No current workers.'
    end
  end

end