# frozen_string_literal: true

require 'action_mailer'
raise 'baw-workers/patches not loaded' unless defined?(Resque::Plugins::Status::EXPIRE_STATUSES)

module BawWorkers
  class Config
    class << self
      attr_accessor :logger_worker,
                    :logger_mailer,
                    :logger_audio_tools,
                    :mailer,
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
        is_resque_worker_fg = BawWorkers::Settings.resque.background_pid_file.blank?

        # configure basic attributes first
        settings = BawWorkers::Settings
        configure_paths(settings)
        BawWorkers::Config.worker_top_dir = default_used ? BawWorkers::Config.temp_dir : File.dirname(settings_file)
        BawWorkers::Config.programs_dir = File.expand_path(BawWorkers::Settings.paths.programs_dir)

        configure_storage(settings)

        # configure logging
        configure_worker_logger(settings, is_resque_worker, is_resque_worker_fg)

        # configure Resque
        configure_redis(is_redis, is_test, settings)
        configure_resque(settings)

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
        raise StandardError, 'run_web: BawWorkers::Settings were nil but should be defined' if BawWorkers::Settings.nil?
        if settings != BawWorkers::Settings
          raise StandardError, 'run_web:  BawWorkers::Settings should be identical to Settings'
        end

        # configure basic attributes first
        configure_paths(settings)
        configure_storage(settings)

        # configure logging
        configure_web_logger(core_logger, mailer_logger, audio_tools_logger, resque_logger)

        # configure Resque
        configure_redis(true, is_test, settings)
        configure_resque(settings)

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
          default_configs.push(provided)
        end

        unless File.file?(default_configs.last)
          message = "The last settings must exist and yet the file could not be found: '#{default_configs.last}'."
          raise BawAudioTools::Exceptions::FileNotFoundError, message
        end

        [default_configs, default_used]
      end

      def load_settings(config_files)
        ::Config.load_and_set_settings(config_files)

        puts "BawWorkers::Settings loaded from #{BawWorkers::Settings.sources}"
      end

      # Configures redis connections for both Resque and our own Redis wrapper
      def configure_redis(needs_redis, _is_test, settings)
        return unless needs_redis

        Resque.redis = ActiveSupport::HashWithIndifferentAccess.new(settings.resque.connection)
        communicator_redis = Redis.new(ActiveSupport::HashWithIndifferentAccess.new(settings.redis.connection))

        Resque.redis.namespace = BawWorkers::Settings.resque.namespace

        # Set up standard redis wrapper.
        BawWorkers::Config.redis_communicator = BawWorkers::RedisCommunicator.new(
          BawWorkers::Config.logger_worker,
          communicator_redis
          # options go here if defined
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

      def configure_web_logger(core_logger, mailer_logger, audio_tools_logger, resque_logger)
        BawWorkers::Config.logger_worker = core_logger
        BawWorkers::Config.logger_mailer = mailer_logger
        BawWorkers::Config.logger_audio_tools = audio_tools_logger

        # then configure attributes that depend on other attributes
        Resque.logger = resque_logger
      end

      def configure_worker_logger(settings, is_resque_worker, is_resque_worker_fg)
        BawWorkers::Config.logger_worker = MultiLogger.new
        BawWorkers::Config.logger_mailer = MultiLogger.new
        BawWorkers::Config.logger_audio_tools = MultiLogger.new

        # always log to dedicated log files
        worker_open = File.open(settings.paths.worker_log_file, 'a+')
        worker_open.sync = true
        BawWorkers::Config.logger_worker.attach(Logger.new(worker_open))

        mailer_open = File.open(settings.paths.mailer_log_file, 'a+')
        mailer_open.sync = true
        BawWorkers::Config.logger_mailer.attach(Logger.new(mailer_open))

        audio_tools_open = File.open(settings.paths.audio_tools_log_file, 'a+')
        audio_tools_open.sync = true
        BawWorkers::Config.logger_audio_tools.attach(Logger.new(audio_tools_open))

        if (is_resque_worker && !is_resque_worker_fg) || BawApp.test?
          # when running a Resque worker in bg, or running in a test, redirect stdout and stderr to files
          stdout_log_file = File.expand_path(settings.resque.output_log_file)
          $stdout = File.open(stdout_log_file, 'a+')
          $stdout.sync = true

          stderr_log_file = File.expand_path(settings.resque.error_log_file)
          $stderr = File.open(stderr_log_file, 'a+')
          $stderr.sync = true

        else
          # all other times, log to console as well
          $stdout.sync = true
          BawWorkers::Config.logger_worker.attach(Logger.new($stdout))
          BawWorkers::Config.logger_mailer.attach(Logger.new($stdout))
          BawWorkers::Config.logger_audio_tools.attach(Logger.new($stdout))

        end

        # set log levels from settings file
        BawWorkers::Config.logger_worker.level = settings.resque.log_level.constantize
        BawWorkers::Config.logger_mailer.level = settings.mailer.log_level.constantize
        BawWorkers::Config.logger_audio_tools.level = settings.audio_tools.log_level.constantize

        # then configure attributes that depend on other attributes

        Resque.logger = BawWorkers::Config.logger_worker
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
          ActionMailer::Base.smtp_settings = BawWorkers::Validation.deep_symbolize_keys(settings.mailer.smtp)
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

      def configure_resque(_settings)
        # resque job status expiry for job status entries
        Resque::Plugins::Status::Hash.expire_in = (24 * 60 * 60) # 24hrs / 1 day in seconds
      end

      def configure_resque_worker
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

        raise 'Resque overwrote the default formatter!'
      end

      def format_result(settings, is_test, context, settings_files)
        result = {
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
        result
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
