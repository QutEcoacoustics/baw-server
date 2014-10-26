require 'rake'
require 'resque/tasks'
require 'baw-workers'

namespace :baw do
  namespace :worker do

    # Set up the worker parameters. Takes one argument: settings_file
    desc 'Run setup for Resque worker'
    task :setup, [:settings_file] => %w(baw:common:init_resque_worker baw:common:init_redis) do |t, args|

      if BawWorkers::Settings.resque.background_pid_file.blank?
        BawWorkers::Config.logger_worker.info('rake_task:baw:worker:setup') {
          'Resque worker will run in foreground.'
        }
      else
        BawWorkers::Config.logger_worker.info('rake_task:baw:worker:setup') {
          "Resque worker will run in background with pid file #{BawWorkers::Settings.resque.background_pid_file}."
        }
        ENV['PIDFILE'] = BawWorkers::Settings.resque.background_pid_file
        ENV['BACKGROUND'] = 'yes'
      end

      queues = BawWorkers::Settings.resque.queues_to_process.join(',')

      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:setup') {
        "Resque worker will poll queues #{queues}."
      }

      ENV['QUEUES'] = queues

      # set resque verbose on
      ENV['VERBOSE '] = '1'
      ENV['VVERBOSE '] = '1'

      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:setup') {
        "Resque worker will poll every #{BawWorkers::Settings.resque.polling_interval_seconds} seconds."
      }

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
    task :run, [:settings_file] => [:setup] do |t, args|

      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:stop_all') {
        'Resque worker starting...'
      }

      # invoke the resque rake task
      Rake::Task['resque:work'].invoke
    end

    desc 'Quit running workers'
    task :stop_all, [:settings_file] => [:current] do |t, args|

      pids = []
      Resque.workers.each do |worker|
        pids.concat(worker.worker_pids)
      end

      pids = pids.uniq

      BawWorkers::Config.logger_worker.info('rake_task:baw:worker:stop_all') {
        "Pids of running Resque workers: #{pids.join(',')}."
      }

      unless pids.empty?
        syscmd = "kill -s QUIT #{pids.join(' ')}"

        BawWorkers::Config.logger_worker.warn('rake_task:baw:worker:stop_all') {
          "Running syscmd to kill all workers: #{syscmd}"
        }

        system(syscmd)
      end
    end

    desc 'List running workers'
    task :current, [:settings_file] => %w(baw:common:init_resque_worker baw:common:init_redis) do |t, args|
      workers = Resque.workers

      if workers.size > 0

        BawWorkers::Config.logger_worker.info('rake_task:baw:worker:current') {
          "There are #{workers.size} Resque workers currently running."
        }

        running_workers = []
        workers.each do |worker|
          running_workers.push(worker.to_s)
        end

        BawWorkers::Config.logger_worker.info('rake_task:baw:worker:current') {
          worker_details = running_workers.map { |worker|
            host, pid, queues = worker.split(':')
            {host: host, pid: pid, queues: queues.join('|')}
          }.join(',')

          "Resque worker details: #{worker_details}."
        }

      else
        BawWorkers::Config.logger_worker.info('rake_task:baw:worker:current') {
          'No Resque workers currently running.'
        }
      end
    end

  end
end