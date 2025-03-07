# frozen_string_literal: true

require 'rake'
require 'resque/tasks'

#
# NOTE: This is an entrypoint for workers. DO NOT require this file from rails
# application
#
require "#{__dir__}/../../../../baw-app/lib/baw_app"

namespace :baw do
  def init(is_worker: false, settings_file: nil, is_scheduler: false)
    BawApp.setup(settings_file)

    # initialize the app
    # baw-app, the workers code, and all other requires are done through rails
    # initialization in application.rb and then in other initializers.
    # Be VERY careful changing the order of things here. It breaks in very
    # subtle ways.
    # For example, requiring baw_app will mean the ruby-config settings won't
    # detect the rails constant and won't add the Rails railtie, and thus the settings
    # won't load! ... but only for workers and not the rails server!
    # We now force load the config railtie in application.rb!
    require(BawApp.root / 'config/application')

    # set time zone
    Time.zone = 'UTC'

    BawWorkers::Config.set(is_resque_worker: is_worker, is_scheduler:)

    # Initialize the Rails application.
    Rails.application.initialize!

    # which in turns run BawWorkers::Config.run from an initializer
  end

  namespace :worker do
    # run a worker. Passes parameter to prerequisite 'setup_worker'. Takes one argument: settings_file
    # start examples:
    # bundle exec rake baw_workers:run_worker
    # bundle exec rake baw_workers:run_worker['/home/user/folder/workers/settings.media.yml']
    # stopping workers:
    # kill -s QUIT $(/home/user/folder/workers/media.pid)
    desc 'Run a resque:work with the specified settings file.'
    task :setup, [:settings_file] do |_t, args|
      init(is_worker: true, settings_file: args.settings_file)
    end

    desc 'Run a resque:work with the specified settings file.'
    task :run, [:settings_file] => [:setup] do |_t, _args|
      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:run') do
        'Resque worker starting...'
      end

      # invoke the resque rake task
      Rake::Task['resque:work'].invoke
    end

    desc 'Run the resque scheduler with the specified settings file.'
    task :run_scheduler, [:settings_file] do |_t, args|
      init(is_worker: false, settings_file: args.settings_file, is_scheduler: true)
      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:run_scheduler') do
        'Resque scheduler starting...'
      end

      require 'resque/scheduler/tasks'
      require 'resque-scheduler'

      # import schedules for our application jobs
      Resque::Scheduler.dynamic = true

      # NOTE: we disable recurring jobs by default on our test scheduler
      # because extra enqueued jobs while other tests are running would break
      # so many things.
      if BawApp.test?
        Rails.logger.warn(
          'Resque scheduler is running in test mode. JOB SCHEDULES HAVE NOT BEEN SET AUTOMATICALLY.'
        )
      else
        BawWorkers::ResqueApi.create_all_schedules
      end

      # invoke the resque rake task
      Rake::Task['resque:scheduler'].invoke
    end

    desc 'List running workers'
    task :current, [:settings_file] do |_t, args|
      init(settings_file: args.settings_file)
      BawWorkers::ResqueApi.workers_running
    end

    desc 'Quit running workers'
    task :stop_all, [:settings_file] do |_t, args|
      init(settings_file: args.settings_file)
      BawWorkers::ResqueApi.workers_running
      BawWorkers::ResqueApi.workers_stop_all
    end

    desc 'Clear queue'
    task :clear_queue, [:settings_file, :queue_name] do |_t, args|
      init(settings_file: args.settings_file)
      BawWorkers::ResqueApi.clear_queue(args.queue_name)
    end

    desc 'Clear stats'
    task :clear_stats, [:settings_file] do |_t, args|
      init(settings_file: args.settings_file)
      BawWorkers::ResqueApi.clear_stats
    end

    desc 'Retry failed jobs'
    task :retry_failed, [:settings_file] do |_t, args|
      init(settings_file: args.settings_file)
      BawWorkers::ResqueApi.retry_failed
    end
  end

  namespace :audio_check do
    namespace :resque do
      desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
      task :from_csv, [:settings_file, :csv_file, :real_run] do |_t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        init(settings_file: args.settings_file)
        BawWorkers::Jobs::AudioCheck::Action.action_enqueue_rake(args.csv_file, is_real_run)
      end
    end
    namespace :standalone do
      desc 'Directly run audio recording file checks from a csv file'
      task :from_csv, [:settings_file, :csv_file, :real_run] do |_t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        init(settings_file: args.settings_file)
        BawWorkers::Jobs::AudioCheck::Action.action_perform_rake(args.csv_file, is_real_run)
      end

      desc 'Test reading csv files'
      task :test_csv, [:audio_recordings_csv, :hash_csv, :result_csv] do |_t, args|
        init(settings_file: args.settings_file)
        BawWorkers::Jobs::AudioCheck::CsvHelper.write_audio_recordings_csv(
          args.audio_recordings_csv, args.hash_csv, args.result_csv
        )
      end

      desc 'Extract CSV lines from a log file'
      task :extract_csv_from_log, [:log_file, :output_file] do |_t, args|
        init(settings_file: args.settings_file)
        BawWorkers::Jobs::AudioCheck::CsvHelper.extract_csv_logs(args.log_file, args.output_file)
      end

      desc 'Confirm database and audio files match'
      task :compare, [:settings_file, :csv_file] do |_t, args|
        init(settings_file: args.settings_file)
        BawWorkers::Jobs::AudioCheck::CsvHelper.compare_csv_db(args.csv_file)
      end
    end
  end

  namespace :harvest do
    desc 'Enqueue files to harvest using Resque'
    task :scan, [:real_run] => ['baw:worker:setup'] do |_t, args|
      args.with_defaults(real_run: 'dry_run')
      is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
      invoke_dir = Rake.original_dir
      BawWorkers::Jobs::Harvest::Enqueue.scan(invoke_dir, is_real_run)
    end
  end

  namespace :media do
    # No rake tasks - media cutting and spectrogram generation is done on demand for now
    # If eager generation is needed, rake tasks can be made to enqueue jobs or run standalone
    # Consider defaults and offsets: from start of file, or from time of day e.g. 22:54:00 / 22:54:30 for 30 second segments?
    # This could be created for eager caching
  end
end

# if no arguments, list available tasks
task :default do
  Rake.application.options.show_tasks = :tasks
  Rake.application.options.show_task_pattern = //
  Rake.application.display_tasks_and_comments
end
