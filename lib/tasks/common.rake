require 'rake'
require 'baw-workers'

namespace :baw do
  namespace :common do

    desc 'Load settings'
    task :init_settings, [:settings_file] do |t, args|
      args.with_defaults(settings_file: File.join(File.dirname(__FILE__), '..', 'settings', 'settings.default.yml'))

      BawWorkers::Config.set_settings_source(args.settings_file)
    end

    desc 'Connect to Redis'
    task :init_redis, [:settings_file] => [:init_settings] do |t, args|
      BawWorkers::Config.logger_worker.info('rake_task:baw:common:init_redis') {
        "Connecting to Redis using namespace #{BawWorkers::Settings.resque.namespace} and connection #{BawWorkers::Settings.resque.connection}."
      }
      Resque.redis = BawWorkers::Settings.resque.connection
      Resque.redis.namespace = BawWorkers::Settings.resque.namespace
    end

    desc 'Configure Resque worker'
    task :init_resque_worker, [:settings_file] => [:init_settings] do |t, args|
      if ENV['RUNNING_RSPEC'] != 'yes'

        if BawWorkers::Settings.resque.background_pid_file.blank?
          # running in foreground
          BawWorkers::Config.set_logger_console_and_file
        else
          # running in background
          BawWorkers::Config.set_logger_files
          BawWorkers::Config.set_console_to_file
        end

        BawWorkers::Config.set_logger_levels
        BawWorkers::Config.set_mailer
        BawWorkers::Config.set_common
        BawWorkers::Config.set_api

      end

      BawWorkers::Config.logger_worker.info('rake_task:baw:common:init_resque_worker') {
        "Logging at level #{BawWorkers::Config.logger_worker.level}."
      }

    end

    desc 'Configure rake task'
    task :init_rake_task, [:settings_file] => [:init_settings] do |t, args|
      if ENV['RUNNING_RSPEC'] != 'yes'
        BawWorkers::Config.set_logger_files
        BawWorkers::Config.set_logger_levels
        BawWorkers::Config.set_mailer
        BawWorkers::Config.set_common
        BawWorkers::Config.set_api
      end

      BawWorkers::Config.logger_worker.info('rake_task:baw:common:init_resque_worker') {
        "Logging at level #{BawWorkers::Config.logger_worker.level}."
      }

    end

  end
end