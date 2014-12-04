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

  end

  namespace :analysis do
    namespace :resque do
      desc 'Enqueue files to analyse using Resque'
      task :from_files, [:settings_file, :analysis_config_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::Analysis::Action.action_enqueue_rake(args.analysis_config_file)
      end
    end
    namespace :standalone do
      desc 'Directly analyse audio files'
      task :from_files, [:settings_file, :analysis_config_file] do |t, args|
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::Analysis::Action.action_perform_rake(args.analysis_config_file)
      end
    end
  end

  namespace :audio_check do
    namespace :resque do
      desc 'Enqueue audio recording file checks from a csv file to be processed using Resque worker'
      task :from_csv, [:settings_file, :csv_file, :dry_run] do |t, args|
        args.with_defaults(dry_run: 'dry_run') # 'real' for non-dry run
        is_dry_run = check_dry_run(args.dry_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::AudioCheck::Action.action_enqueue_rake(args.csv_file, is_dry_run)
      end
    end
    namespace :standalone do
      desc 'Directly run audio recording file checks from a csv file'
      task :from_csv, [:settings_file, :csv_file, :dry_run] do |t, args|
        args.with_defaults(dry_run: 'dry_run') # 'real' for non-dry run
        is_dry_run = check_dry_run(args.dry_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::AudioCheck::Action.action_perform_rake(args.csv_file, is_dry_run)
      end
    end
  end

  namespace :harvest do
    namespace :resque do
      desc 'Enqueue files to harvest using Resque'
      task :from_files, [:settings_file, :harvest_dir, :dry_run] do |t, args|
        args.with_defaults(dry_run: 'dry_run') # 'real' for non-dry run
        is_dry_run = check_dry_run(args.dry_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: true, resque_worker: false)
        BawWorkers::Harvest::Action.action_enqueue_rake(args.harvest_dir, is_dry_run)
      end
    end
    namespace :standalone do
      desc 'Directly harvest audio files'
      task :from_files, [:settings_file, :harvest_dir, :dry_run] do |t, args|
        args.with_defaults(dry_run: 'dry_run') # 'real' for non-dry run
        is_dry_run = check_dry_run(args.dry_run)
        BawWorkers::Config.run(settings_file: args.settings_file, redis: false, resque_worker: false)
        BawWorkers::Harvest::Action.action_perform_rake(args.harvest_dir, is_dry_run)
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