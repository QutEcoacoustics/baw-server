# frozen_string_literal: true

require 'action_mailer'
raise 'modified resque status hash class not loaded' unless defined?(Resque::Plugins::Status::EXPIRE_STATUSES)

module BawWorkers
  class Config
    class << self
      # @return [BawWorkers::MultiLogger]
      attr_reader :logger_worker

      # @return [BawWorkers::MultiLogger]
      attr_reader :logger_mailer

      # @return [BawWorkers::MultiLogger]
      attr_reader :logger_audio_tools

      attr_accessor :mailer,
                    :temp_dir,
                    :worker_top_dir,
                    :programs_dir,
                    :spectrogram_helper,
                    :audio_helper,
                    :original_audio_helper,
                    :audio_cache_helper,
                    :spectrogram_cache_helper,
                    :analysis_cache_helper,
                    :file_info,
                    :api_communicator,
                    :redis_communicator

      # @return [BawWorkers::UploadService::Communicator]
      attr_reader :upload_communicator

      # Set up configuration from settings file.
      # @param [Hash] opts
      # @option opts [String] :settings_file (nil) path to settings file
      # @option opts [Boolean] :redis (false) is redis needed?
      # @option opts [Boolean] :resque_worker (false) are we running in the context of a Resque worker?
      # @return [Hash] configuration result
      def run(opts)
        settings_files, default_used = use_supplied_config_or_default(opts)

        load_settings(settings_files)

        # easy access to options
        is_test = BawApp.test?
        is_redis = opts.include?(:redis) && opts[:redis]
        is_resque_worker = opts.include?(:resque_worker) && opts[:resque_worker]
        is_resque_worker_fg = Settings.resque.background_pid_file.blank?

        # configure basic attributes first
        settings = Settings
        configure_paths(settings)
        BawWorkers::Config.worker_top_dir = default_used ? BawWorkers::Config.temp_dir : File.dirname(settings_files.last)
        BawWorkers::Config.programs_dir = File.expand_path(Settings.paths.programs_dir)

        configure_storage(settings)

        # configure logging
        configure_worker_logger(settings, is_resque_worker, is_resque_worker_fg)

        configure_upload_service(settings)

        # configure Resque
        configure_redis(is_redis, is_test, settings)
        configure_resque(settings, BawWorkers::Config.logger_worker)

        # resque job status expiry for job status entries
        Resque::Plugins::Status::Hash.expire_in = (24 * 60 * 60) # 24hrs / 1 day in seconds

        configure_mailer(settings)

        # configure complex attributes
        configure_audio_helper(settings)
        configure_spectrogram_helper(settings)
        configure_api_communicator(settings)
        BawWorkers::Config.file_info = FileInfo.new(BawWorkers::Config.audio_helper)

        # configure resque worker
        configure_resque_worker if is_resque_worker

        result = format_result(settings, is_test, 'worker', settings_files)
        result = format_resque_worker(result, is_resque_worker, is_resque_worker_fg)

        check_resque_formatter

        log_info result
      end

      def run_web(core_logger, mailer_logger, resque_logger, audio_tools_logger, settings)
        is_test = BawApp.test?

        # assert settings is a singleton
        raise StandardError, 'run_web: Settings should have already been initialized' if settings.nil?
        raise StandardError, 'run_web: Settings were nil but should be defined' if Settings.nil?
        raise StandardError, 'run_web:  Settings should be identical to Settings' if settings != Settings

        # configure basic attributes first
        configure_paths(settings)
        configure_storage(settings)

        # configure logging
        configure_web_logger(core_logger, mailer_logger, audio_tools_logger)

        configure_upload_service(settings)

        # configure Resque
        configure_redis(true, is_test, settings)
        configure_resque(settings, resque_logger)

        # configure mailer
        configure_mailer(settings)

        # configure complex attributes
        configure_audio_helper(settings)
        configure_spectrogram_helper(settings)
        configure_api_communicator(settings)
        BawWorkers::Config.file_info = FileInfo.new(BawWorkers::Config.audio_helper)

        result = format_result(settings, is_test, 'web', nil)

        check_resque_formatter

        log_info result
      end

      private

      def use_supplied_config_or_default(opts)
        default_configs = BawApp.config_files

        default_used = false
        if !opts.include?(:settings_file) || opts[:settings_file].blank?
          default_used = true
        else
          provided = File.expand_path(opts[:settings_file])
          default_configs += [provided]
        end

        unless File.file?(default_configs.last)
          message = "The last settings must exist and yet the file could not be found: '#{default_configs.last}'."
          raise BawAudioTools::Exceptions::FileNotFoundError, message
        end

        [default_configs, default_used]
      end

      def load_settings(config_files)
        ::Config.load_and_set_settings(config_files)
      end

      # Configures redis connections for both Resque and our own Redis wrapper
      def configure_redis(needs_redis, _is_test, settings)
        return unless needs_redis

        communicator_redis = Redis.new(ActiveSupport::HashWithIndifferentAccess.new(settings.redis.connection))

        # Set up standard redis wrapper.
        BawWorkers::Config.redis_communicator = BawWorkers::RedisCommunicator.new(
          BawWorkers::Config.logger_worker,
          communicator_redis,
          # options go here if defined
          {
            namespace: settings.redis.namespace
          }
        )
      end

      def configure_paths(settings)
        BawWorkers::Config.temp_dir = File.expand_path(settings.paths.temp_dir)
      end

      def configure_storage(settings)
        BawWorkers::Config.original_audio_helper = BawWorkers::Storage::AudioOriginal.new(
          settings.paths.original_audios
        )
        BawWorkers::Config.audio_cache_helper = BawWorkers::Storage::AudioCache.new(
          settings.paths.cached_audios
        )
        BawWorkers::Config.spectrogram_cache_helper = BawWorkers::Storage::SpectrogramCache.new(
          settings.paths.cached_spectrograms
        )
        BawWorkers::Config.analysis_cache_helper = BawWorkers::Storage::AnalysisCache.new(
          settings.paths.cached_analysis_jobs
        )
      end

      def configure_upload_service(settings)
        @upload_communicator = BawWorkers::UploadService::Communicator.new(
          config: settings.upload_service,
          logger: BawWorkers::Config.logger_worker
        )
      end

      def configure_web_logger(core_logger, mailer_logger, audio_tools_logger)
        @logger_worker = core_logger
        @logger_mailer = mailer_logger
        @logger_audio_tools = audio_tools_logger
      end

      def configure_worker_logger(settings, is_resque_worker, is_resque_worker_fg)
        running_in_bg = is_resque_worker && !is_resque_worker_fg

        prepare_logger = lambda { |path, log_to_console|
          # always log to dedicated log files
          logger_io = File.open(path, 'a+')
          logger_io.sync = true
          file_logger = Logger.new(logger_io)

          # send log messages to stdout
          console_logger = log_to_console ? Logger.new($stdout) : nil
          MultiLogger.new(file_logger, console_logger)
        }

        @logger_worker = prepare_logger.call(settings.paths.worker_log_file, !running_in_bg)
        @logger_mailer = prepare_logger.call(settings.paths.mailer_log_file, !running_in_bg)
        @logger_audio_tools = prepare_logger.call(settings.paths.audio_tools_log_file, !running_in_bg)

        # when running in background we can't see stdout/stderr, so log them to files
        if running_in_bg
          $stdout = File.open(File.expand_path(settings.resque.output_log_file), 'a+')
          $stderr = File.open(File.expand_path(settings.resque.error_log_file), 'a+')
        end

        $stdout.sync = true
        $stderr.sync = true

        # set log levels from settings file
        BawWorkers::Config.logger_worker.level = settings.resque.log_level.constantize
        BawWorkers::Config.logger_mailer.level = settings.mailer.log_level.constantize
        BawWorkers::Config.logger_audio_tools.level = settings.audio_tools.log_level.constantize
      end

      def configure_mailer(settings)
        ActionMailer::Base.logger = BawWorkers::Config.logger_mailer
        ActionMailer::Base.raise_delivery_errors = true
        ActionMailer::Base.perform_deliveries = true
        # ActionMailer::Base.view_paths = [
        #     File.expand_path(File.join(File.dirname(__FILE__), 'mail'))
        # ]

        if BawApp.development?
          ActionMailer::Base.delivery_method = :file
          ActionMailer::Base.file_settings =
            {
              location: File.join(BawWorkers::Config.temp_dir, 'mail')
            }
        elsif BawApp.test?
          ActionMailer::Base.delivery_method = :test
          ActionMailer::Base.smtp_settings = nil
        else
          ActionMailer::Base.delivery_method = :smtp
          ActionMailer::Base.smtp_settings = settings.mailer.smtp.to_h
        end
      end

      def configure_audio_helper(settings)
        BawWorkers::Config.audio_helper = BawAudioTools::AudioBase.from_executables(
          settings.cached_audio_defaults,
          BawWorkers::Config.logger_audio_tools,
          BawWorkers::Config.temp_dir,
          settings.audio_tools_timeout_sec,
          ffmpeg: settings.audio_tools.ffmpeg_executable,
          ffprobe: settings.audio_tools.ffprobe_executable,
          mp3splt: settings.audio_tools.mp3splt_executable,
          sox: settings.audio_tools.sox_executable,
          wavpack: settings.audio_tools.wavpack_executable,
          shntool: settings.audio_tools.shntool_executable
        )
      end

      def configure_spectrogram_helper(settings)
        BawWorkers::Config.spectrogram_helper = BawAudioTools::Spectrogram.from_executables(
          BawWorkers::Config.audio_helper,
          settings.audio_tools.imagemagick_convert_executable,
          settings.audio_tools.imagemagick_identify_executable,
          settings.cached_spectrogram_defaults,
          BawWorkers::Config.temp_dir
        )
      end

      def configure_api_communicator(settings)
        BawWorkers::Config.api_communicator = BawWorkers::ApiCommunicator.new(
          BawWorkers::Config.logger_worker,
          settings.api,
          settings.endpoints
        )
      end

      def configure_resque(settings, resque_logger)
        # resque job status expiry for job status entries
        Resque::Plugins::Status::Hash.expire_in = (24 * 60 * 60) # 24hrs / 1 day in seconds

        Resque.redis = ActiveSupport::HashWithIndifferentAccess.new(settings.resque.connection)
        Resque.redis.namespace = Settings.resque.namespace

        Resque.logger = resque_logger
      end

      def configure_resque_worker
        if Settings.resque.background_pid_file.blank?
          ENV['PIDFILE'] = nil
          ENV['BACKGROUND'] = nil
        else
          ENV['PIDFILE'] = Settings.resque.background_pid_file
          ENV['BACKGROUND'] = 'yes'
        end

        ENV['QUEUES'] = Settings.resque.queues_to_process.join(',')
        ENV['INTERVAL'] = Settings.resque.polling_interval_seconds.to_s

        # set resque verbose on
        #ENV['VERBOSE '] = '1'
        #ENV['VVERBOSE '] = '1'

        # use new signal handling
        # http://hone.heroku.com/resque/2012/08/21/resque-signals.html
        #ENV['TERM_CHILD'] = '1'
      end

      def check_resque_formatter
        # temporary hack - v1.26 of Resque overrides our default formatter.
        # This is the fix for the bug https://github.com/resque/resque/commit/eaaac2acc209456cdd0dd794d2d3714968cf76e4
        # This is a new behaviour that I can't replicate in a dev environment - which
        # I now suspect is because we call .verbose somewhere.
        # The formatter resque uses is the QuietFormatter and it literally just
        # writes out an empty string whenever a log statement is run. As near as I can tell this overwrite happens
        # either in Resque.info or one of the other Resque related functions in the result block above.
        # It is also happens when workers are created which means patching the formatter below wouldn't work properly.
        # Now instead of patching, just don't even start - fail fast!
        return if BawWorkers::Config.logger_worker.formatter.is_a?(BawWorkers::MultiLogger::CustomFormatter)

        warn 'WARNING: Resque overwrote the default formatter!'

        # when this is no longer an issue remove exception in lib/gems/baw-workers/lib/baw_workers/multi_logger.rb#formatter=

        BawWorkers::Config.logger_worker.formatter = BawWorkers::MultiLogger::CustomFormatter.new
      end

      def format_result(settings, is_test, context, settings_files)
        {
          context: context,
          settings: {
            test: is_test,
            environment: BawApp.env,
            files: settings_files,
            run_dir: BawWorkers::Config.worker_top_dir,
            is_development: BawApp.development?
          },
          redis: {
            namespace: Resque.redis.namespace.to_s,
            connection: settings.resque.connection,
            info: Resque.info
          },
          resque: {
            status: {
              expire_in: Resque::Plugins::Status::Hash.expire_in
            }
          },
          logging: {
            worker: BawWorkers::Config.logger_worker.level,
            mailer: BawWorkers::Config.logger_mailer.level,
            audio_tools: BawWorkers::Config.logger_audio_tools.level,
            resque: Resque.logger.level
          }
        }
      end

      def format_resque_worker(result, is_resque_worker, is_resque_worker_fg)
        result[:resque_worker] = {
          running: is_resque_worker,
          mode: is_resque_worker_fg ? 'fg' : 'bg',
          pid_file: is_resque_worker ? ENV['PIDFILE'] : nil,
          queues: is_resque_worker ? ENV['QUEUES'] : nil,
          poll_interval: is_resque_worker ? ENV['INTERVAL'].to_f : nil
        }
        result
      end

      def log_info(result)
        BawWorkers::Config.logger_worker.warn('BawWorkers::Config') {
          JSON.fast_generate result
        }
      end
    end
  end
end
