require 'rake'
require 'resque/tasks'
require 'baw-workers'

namespace :baw do

  namespace :worker do

    # run a worker. Passes parameter to prerequisite 'setup_worker'. Takes one argument: settings_file
    # start examples:
    # bundle exec rake baw_workers:run_worker
    # bundle exec rake baw_workers:run_worker['/home/user/folder/workers/settings.media.yml']
    # stopping workers:
    # kill -s QUIT $(/home/user/folder/workers/media.pid)
    desc 'Run a resque:work with the specified settings file.'
    task :setup, [:settings_file] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: true)
    end

    desc 'Run a resque:work with the specified settings file.'
    task :run, [:settings_file] => [:setup] do |t, args|
      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:run') {
        'Resque worker starting...'
      }

      # invoke the resque rake task
      Rake::Task['resque:work'].invoke
    end

    desc 'List running workers'
    task :current, [:settings_file] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
      BawWorkers::ResqueApi.workers_running
    end

    desc 'Quit running workers'
    task :stop_all, [:settings_file] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
      BawWorkers::ResqueApi.workers_running
      BawWorkers::ResqueApi.workers_stop_all
    end

    desc 'Clear queue'
    task :clear_queue, [:settings_file, :queue_name] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
      BawWorkers::ResqueApi.clear_queue(args.queue_name)
    end

    desc 'Clear stats'
    task :clear_stats, [:settings_file,] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
      BawWorkers::ResqueApi.clear_stats
    end

    desc 'Retry failed jobs'
    task :retry_failed, [:settings_file,] do |t, args|
      BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
      BawWorkers::ResqueApi.retry_failed
    end

  end

  namespace :analysis do
    namespace :resque do
      desc 'Enqueue a file to analyse using Resque'
      task :from_files, [:settings_file, :analysis_config_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::Analysis::Action.action_enqueue_rake(args.analysis_config_file)
      end

      desc 'Enqueue files to analyse using Resque from a csv file'
      task :from_csv, [:settings_file, :csv_file, :config_file, :command_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::Analysis::Action.action_enqueue_rake_csv(args.csv_file, args.config_file, args.command_file)
      end

    end
    namespace :standalone do
      desc 'Directly analyse an audio file'
      task :from_files, [:settings_file, :analysis_config_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::Analysis::Action.action_perform_rake(args.analysis_config_file)
      end

      desc 'Directly analyse audio files from csv file'
      task :from_csv, [:settings_file, :csv_file, :config_file, :command_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::Analysis::Action.action_perform_rake_csv(args.csv_file, args.config_file, args.command_file)
      end
    end
  end

  namespace :audio_check do
    namespace :resque do
      desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
      task :from_csv, [:settings_file, :csv_file, :real_run] do |t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::AudioCheck::Action.action_enqueue_rake(args.csv_file, is_real_run)
      end
    end
    namespace :standalone do
      desc 'Directly run audio recording file checks from a csv file'
      task :from_csv, [:settings_file, :csv_file, :real_run] do |t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::AudioCheck::Action.action_perform_rake(args.csv_file, is_real_run)
      end

      desc 'Test reading csv files'
      task :test_csv, [:audio_recordings_csv, :hash_csv, :result_csv] do |t, args|
        BawWorkers::AudioCheck::CsvHelper.write_audio_recordings_csv(
            args.audio_recordings_csv, args.hash_csv, args.result_csv)
      end

      desc 'Extract CSV lines from a log file'
      task :extract_csv_from_log, [:log_file, :output_file] do |t, args|
        BawWorkers::AudioCheck::CsvHelper.extract_csv_logs(args.log_file, args.output_file)
      end

      desc 'Confirm database and audio files match'
      task :compare, [:settings_file, :csv_file] do | t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::AudioCheck::CsvHelper.compare_csv_db(args.csv_file)
      end
    end
  end

  namespace :harvest do
    namespace :resque do
      desc 'Enqueue files to harvest using Resque'
      task :from_files, [:settings_file, :harvest_dir, :real_run, :copy_on_success] do |t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        copy_on_success = BawWorkers::Validation.should_copy_on_success?(args.copy_on_success)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::Harvest::Action.action_enqueue_rake(args.harvest_dir, is_real_run, copy_on_success)
      end
    end
    namespace :standalone do
      desc 'Directly harvest audio files'
      task :from_files, [:settings_file, :harvest_dir, :real_run, :copy_on_success] do |t, args|
        args.with_defaults(real_run: 'dry_run')
        is_real_run = BawWorkers::Validation.is_real_run?(args.real_run)
        copy_on_success = BawWorkers::Validation.should_copy_on_success?(args.copy_on_success)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::Harvest::Action.action_perform_rake(args.harvest_dir, is_real_run, copy_on_success)
      end
    end
  end

  namespace :media do
    # No rake tasks - media cutting and spectrogram generation is done on demand for now
    # If eager generation is needed, rake tasks can be made to enqueue jobs or run standalone
    # Consider defaults and offsets: from start of file, or from time of day e.g. 22:54:00 / 22:54:30 for 30 second segments?
    # This could be created for eager caching
  end

end