require 'action_mailer'

module BawWorkers
  class Config

    class << self
      attr_accessor :logger_worker,
                    :logger_mailer,
                    :logger_audio_tools,
                    :mailer,
                    :temp_dir,
                    :spectrogram_helper,
                    :audio_helper,
                    :original_audio_helper,
                    :audio_cache_helper,
                    :spectrogram_cache_helper,
                    :dataset_cache_helper,
                    :analysis_cache_helper,
                    :file_info,
                    :api_communicator

      # Set up configuration from settings file.
      # @param [Hash] opts
      # @option opts [String] :settings_file (nil) path to settings file
      # @option opts [Boolean] :redis (false) is redis needed?
      # @option opts [Boolean] :resque_worker (false) are we running in the context of a Resque worker?
      # @return [Hash] configuration result
      def run(opts = {})
        if !opts.include?(:settings_file) || opts[:settings_file].blank?
          opts[:settings_file] = File.join(File.dirname(__FILE__), '..', 'settings', 'settings.default.yml')
        end

        fail BawAudioTools::Exceptions::FileNotFoundError, "Settings file could not be found: '#{opts[:settings_file]}'." unless File.file?(opts[:settings_file])

        settings_file = File.expand_path(opts[:settings_file])
        settings_namespace = 'settings'

        BawWorkers::Settings.configure(settings_file, settings_namespace)

        # ensure settings are updated if they have already been loaded
        BawWorkers::Settings.instance_merge(settings_file, settings_namespace)

        # easy access to options
        is_test = ENV['RUNNING_RSPEC'] == 'yes'
        is_redis = opts.include?(:redis) && opts[:redis]
        is_resque_worker = opts.include?(:resque_worker) && opts[:resque_worker]
        is_resque_worker_fg = BawWorkers::Settings.resque.background_pid_file.blank?

        # configure basic attributes first
        BawWorkers::Config.temp_dir = File.expand_path(BawWorkers::Settings.paths.temp_dir)

        BawWorkers::Config.original_audio_helper = BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios)
        BawWorkers::Config.audio_cache_helper = BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios)
        BawWorkers::Config.spectrogram_cache_helper = BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms)
        BawWorkers::Config.dataset_cache_helper = BawWorkers::Storage::DatasetCache.new(BawWorkers::Settings.paths.cached_datasets)
        BawWorkers::Config.analysis_cache_helper = BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs)

        # configure logging
        BawWorkers::Config.logger_worker = MultiLogger.new
        BawWorkers::Config.logger_mailer = MultiLogger.new
        BawWorkers::Config.logger_audio_tools = MultiLogger.new

        # always log to dedicate log files
        worker_open = File.open(BawWorkers::Settings.paths.worker_log_file, 'a+')
        worker_open.sync = true
        BawWorkers::Config.logger_worker.attach(Logger.new(worker_open))

        mailer_open = File.open(BawWorkers::Settings.paths.mailer_log_file, 'a+')
        mailer_open.sync = true
        BawWorkers::Config.logger_mailer.attach(Logger.new(mailer_open))

        audio_tools_open = File.open(BawWorkers::Settings.paths.audio_tools_log_file, 'a+')
        audio_tools_open.sync = true
        BawWorkers::Config.logger_audio_tools.attach(Logger.new(audio_tools_open))

        if (is_resque_worker && !is_resque_worker_fg) || is_test
          # when running a Resque worker in bg, or running in a test, redirect stdout and stderr to files
          stdout_log_file = File.expand_path(BawWorkers::Settings.resque.output_log_file)
          $stdout = File.open(stdout_log_file, 'a+')
          $stdout.sync = true

          stderr_log_file = File.expand_path(BawWorkers::Settings.resque.error_log_file)
          $stderr = File.open(stderr_log_file, 'a+')
          $stderr.sync = true

        else
          # all other times, log to console as well
          $stdout.sync = true
          stdout_logger = Logger.new($stdout)
          BawWorkers::Config.logger_worker.attach(stdout_logger)
          BawWorkers::Config.logger_mailer.attach(stdout_logger)
          BawWorkers::Config.logger_audio_tools.attach(stdout_logger)

        end

        # set log levels from settings file
        BawWorkers::Config.logger_worker.level = BawWorkers::Settings.resque.log_level.constantize
        BawWorkers::Config.logger_mailer.level = BawWorkers::Settings.mailer.log_level.constantize
        BawWorkers::Config.logger_audio_tools.level = BawWorkers::Settings.audio_tools.log_level.constantize

        # then configure attributes that depend on other attributes
        BawWorkers::Config.file_info = FileInfo.new(BawWorkers::Config.audio_helper)
        Resque.logger = BawWorkers::Config.logger_worker

        # configure Resque
        if is_redis
          if is_test
            # use fake redis
            Resque.redis = Redis.new
          else
            Resque.redis = BawWorkers::Settings.resque.connection
          end
          Resque.redis.namespace = BawWorkers::Settings.resque.namespace
        end

        # configure mailer
        ActionMailer::Base.logger = BawWorkers::Config.logger_mailer
        ActionMailer::Base.raise_delivery_errors = true
        ActionMailer::Base.perform_deliveries = true
        # ActionMailer::Base.view_paths = [
        #     File.expand_path(File.join(File.dirname(__FILE__), 'mail'))
        # ]

        if is_test
          ActionMailer::Base.delivery_method = :test
          ActionMailer::Base.smtp_settings = nil
        else
          ActionMailer::Base.delivery_method = :smtp
          ActionMailer::Base.smtp_settings = BawWorkers::Validation.deep_symbolize_keys(BawWorkers::Settings.mailer.smtp)
        end

        # configure complex attributes
        BawWorkers::Config.audio_helper = BawAudioTools::AudioBase.from_executables(
            BawWorkers::Settings.cached_audio_defaults,
            BawWorkers::Config.logger_audio_tools,
            BawWorkers::Config.temp_dir,
            BawWorkers::Settings.audio_tools_timeout_sec,
            {
                ffmpeg: BawWorkers::Settings.audio_tools.ffmpeg_executable,
                ffprobe: BawWorkers::Settings.audio_tools.ffprobe_executable,
                mp3splt: BawWorkers::Settings.audio_tools.mp3splt_executable,
                sox: BawWorkers::Settings.audio_tools.sox_executable,
                wavpack: BawWorkers::Settings.audio_tools.wavpack_executable,
                shntool: BawWorkers::Settings.audio_tools.shntool_executable
            })

        BawWorkers::Config.spectrogram_helper = BawAudioTools::Spectrogram.from_executables(
            BawWorkers::Config.audio_helper,
            BawWorkers::Settings.audio_tools.imagemagick_convert_executable,
            BawWorkers::Settings.audio_tools.imagemagick_identify_executable,
            BawWorkers::Settings.cached_spectrogram_defaults,
            BawWorkers::Config.temp_dir)

        BawWorkers::Config.api_communicator = BawWorkers::ApiCommunicator.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Settings.api,
            BawWorkers::Settings.endpoints)

        # configure resque worker
        if is_resque_worker

          if BawWorkers::Settings.resque.background_pid_file.blank?
            ENV['PIDFILE'] = nil
            ENV['BACKGROUND'] = nil
            else
            ENV['PIDFILE'] = BawWorkers::Settings.resque.background_pid_file
            ENV['BACKGROUND'] = 'yes'
          end

          ENV['QUEUES'] = BawWorkers::Settings.resque.queues_to_process.join(',')
          ENV['INTERVAL'] = BawWorkers::Settings.resque.polling_interval_seconds.to_s

          # set resque verbose on
          #ENV['VERBOSE '] = '1'
          #ENV['VVERBOSE '] = '1'

          # use new signal handling
          # http://hone.heroku.com/resque/2012/08/21/resque-signals.html
          #ENV['TERM_CHILD'] = '1'

        end

        result = {
            settings: {
                test: is_test,
                file: settings_file,
                namespace: settings_namespace
            },
            redis: {
                configured: is_redis,
                namespace: is_redis ? Resque.redis.namespace.to_s : nil,
                connection: is_redis ? (is_test ? 'fake' : BawWorkers::Settings.resque.connection) : nil,
                info: is_redis ? Resque.info : nil
            },
            resque_worker: {
                running: is_resque_worker,
                mode: is_resque_worker_fg ? 'fg' : 'bg',
                pid_file: is_resque_worker ? ENV['PIDFILE'] : nil,
                queues: is_resque_worker ? ENV['QUEUES'] : nil,
                poll_interval: is_resque_worker ? ENV['INTERVAL'].to_i : nil

            },
            logging: {
                file_only: (is_resque_worker && !is_resque_worker_fg) || is_test,
                worker: BawWorkers::Config.logger_worker.level,
                mailer: BawWorkers::Config.logger_mailer.level,
                audio_tools: BawWorkers::Config.logger_audio_tools.level
            }
        }

        BawWorkers::Config.logger_worker.warn('BawWorkers::Config') { result.to_json }
      end

    end
  end
end