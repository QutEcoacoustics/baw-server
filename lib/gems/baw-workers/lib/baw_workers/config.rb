# frozen_string_literal: true

module BawWorkers
  class Config
    class << self
      @is_resque_worker = false
      # Is this a resque_worker?
      # @return [Boolean]
      def resque_worker?
        @is_resque_worker
      end

      @is_scheduler = false
      # Is this a scheduler?
      # @return [Boolean]
      def scheduler?
        @is_scheduler
      end

      @is_baw_workers_entry = false
      # Was this process started by the baw-workers executable?
      # @return [Boolean]
      def baw_workers_entry?
        @is_baw_workers_entry
      end

      # @return [::SemanticLogger::Logger]
      attr_reader :logger_worker

      # @return [::SemanticLogger::Logger]
      attr_reader :logger_mailer

      # @return [::SemanticLogger::Logger]
      attr_reader :logger_audio_tools

      # @return [Pathname]
      attr_reader :temp_dir

      # @return [Pathname]
      attr_reader :worker_top_dir

      # @return [Pathname]
      attr_reader :programs_dir

      # @return [BawAudioTools::Spectrogram]
      attr_reader :spectrogram_helper

      # @return [BawAudioTools::AudioBase]
      attr_reader :audio_helper

      # @return [BawWorkers::Storage::AudioOriginal]
      attr_reader :original_audio_helper

      # @return [BawWorkers::Storage::AudioCache]
      attr_reader :audio_cache_helper

      # @return [BawWorkers::Storage::SpectrogramCache]
      attr_reader :spectrogram_cache_helper

      # @return [BawWorkers::Storage::AnalysisCache]
      attr_reader :analysis_cache_helper

      # @return [BawWorkers::FileInfo]
      attr_reader :file_info

      # @return [BawWorkers::RedisCommunicator]
      attr_reader :redis_communicator

      # @return [BawWorkers::UploadService::Communicator]
      attr_reader :upload_communicator

      # @return [BawWorkers::BatchAnalysis::Communicator]
      attr_reader :batch_analysis

      # Adjust initialization context when started from rake task
      # @param [Boolean] :resque_worker (false) are we running in the context of a Resque worker?
      def set(is_resque_worker: false, is_scheduler: false)
        @is_resque_worker = !is_resque_worker.nil?
        @is_scheduler = is_scheduler == true
        @is_baw_workers_entry = true
      end

      # Configure the workers
      # @param [SemanticLogger::Logger] the base log to work with
      # @param [Config::Options] the settings to use
      def run_web(core_logger, settings)
        # assert settings is a singleton
        raise StandardError, 'run_web: Settings should have already been initialized' if settings.nil?
        raise StandardError, 'run_web: Settings were nil but should be defined' if Settings.nil?
        raise StandardError, 'run_web: Settings should be identical to Settings' if settings != Settings

        # configure basic attributes first
        configure_paths(settings, true)
        configure_storage(settings)

        # configure logging
        configure_loggers(core_logger, settings)

        configure_upload_service(settings)

        @batch_analysis = BawWorkers::BatchAnalysis::Communicator.new

        # configure Resque
        configure_redis(settings)
        configure_resque(settings)

        # configure mailer
        configure_mailer(settings)

        # configure complex attributes
        configure_audio_helper(settings)
        configure_spectrogram_helper(settings)

        @file_info = BawWorkers::FileInfo.new(BawWorkers::Config.audio_helper)

        # configure resque worker
        configure_resque_worker if resque_worker?
        configure_scheduler if scheduler?

        result = format_result(settings)
        result = format_resque_worker(result, settings)

        check_resque_formatter

        log_info result
      end

      private

      def baw_workers_mode(settings)
        return :library unless baw_workers_entry?

        return :resque_foreground if settings.resque.background_pid_file.blank?

        :resque_background
      end

      # Configures redis connections for both Resque and our own Redis wrapper
      def configure_redis(settings)
        communicator_redis = Redis.new(Settings.redis.connection.to_h)

        # Set up standard redis wrapper.
        @redis_communicator = BawWorkers::RedisCommunicator.new(
          SemanticLogger[RedisCommunicator],
          communicator_redis,
          # options go here if defined
          {
            namespace: settings.redis.namespace
          }
        )
      end

      def configure_paths(settings, default_used)
        @temp_dir = settings.paths.temp_dir
        @worker_top_dir = default_used ? BawWorkers::Config.temp_dir : Pathname(Fle.dirname(settings_files.last))
        @programs_dir = Settings.paths.programs_dir
      end

      def configure_storage(settings)
        @original_audio_helper = BawWorkers::Storage::AudioOriginal.new(
          settings.paths.original_audios
        )
        @audio_cache_helper = BawWorkers::Storage::AudioCache.new(
          settings.paths.cached_audios
        )
        @spectrogram_cache_helper = BawWorkers::Storage::SpectrogramCache.new(
          settings.paths.cached_spectrograms
        )
        @analysis_cache_helper = BawWorkers::Storage::AnalysisCache.new(
          settings.paths.cached_analysis_jobs
        )
      end

      def configure_upload_service(settings)
        @upload_communicator = BawWorkers::UploadService::Communicator.new(
          config: settings.upload_service,
          logger: BawWorkers::Config.logger_worker
        )
      end

      def configure_loggers(_core_logger, settings)
        @logger_worker = SemanticLogger['BawWorkers']
        @logger_mailer = SemanticLogger['BawWorkers::Mailer']
        @logger_audio_tools = SemanticLogger['BawAudioTools']

        # set log levels from settings file
        #BawWorkers::Config.logger_worker.level
        BawWorkers::Config.logger_mailer.level = settings.mailer.log_level.constantize
        BawWorkers::Config.logger_audio_tools.level = settings.audio_tools.log_level.constantize
      end

      def configure_mailer(_settings)
        # All settings should be set by rails
        return if BawWorkers::Mail::Mailer.logger == BawWorkers::Config.logger_mailer

        raise 'BawWorkers::Mail::Mailer logger incorrect'
      end

      def configure_audio_helper(settings)
        @audio_helper = BawAudioTools::AudioBase.from_executables(
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
        @spectrogram_helper = BawAudioTools::Spectrogram.from_executables(
          BawWorkers::Config.audio_helper,
          settings.audio_tools.imagemagick_convert_executable,
          settings.audio_tools.imagemagick_identify_executable,
          settings.cached_spectrogram_defaults,
          BawWorkers::Config.temp_dir
        )
      end

      def configure_resque(settings)
        Resque.redis = ActiveSupport::HashWithIndifferentAccess.new(settings.resque.connection)
        Resque.redis.namespace = Settings.resque.namespace
        BawWorkers::ActiveJob::Status::Persistance.configure(Resque.redis.redis)
        BawWorkers::ActiveJob::Concurrency::Persistance.configure(Resque.redis.redis)

        # Logger set automatically by SemanticLogger RailTie
        raise 'Resque logger not configured' unless Resque.logger.is_a?(SemanticLogger::Logger)

        Resque.logger.level = settings.resque.log_level.constantize
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

        # ensure resque does not kill workers with exit!
        # Note: do not set this, it will cause failures in retry_on
        #ENV['RUN_AT_EXIT_HOOKS'] = 'true'
        # use new killer, it's a little bit graceful
        ENV['GRACEFUL_TERM'] = 'true'
        ENV['TERM_CHILD'] = 'true'
        # timeout for graceful death
        ENV['RESQUE_TERM_TIMEOUT'] = '10.0'

        # if BawApp.dev_or_test?
        #   Resque.after_fork do
        #     at_exit do
        #       pid = $PROCESS_ID
        #       tid = Thread.current.object_id
        #       error = $ERROR_INFO
        #       puts <<~MSG
        #         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        #         Worker exited! PID: #{pid} TID: #{tid}
        #         Caller: #{caller}
        #         Error: #{error}
        #         @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
        #       MSG
        #       exit!
        #     end
        #   end
        # end
      end

      def configure_scheduler
        Resque::Scheduler.configure do |c|
          c.poll_sleep_amount = Settings.resque.polling_interval_seconds
        end
        # If you want to be able to dynamically change the schedule,
        # uncomment this line.  A dynamic schedule can be updated via the
        # Resque::Scheduler.set_schedule (and remove_schedule) methods.
        # When dynamic is set to true, the scheduler process looks for
        # schedule changes and applies them on the fly.
        # Note: This feature is only available in >=2.0.0.
        #
        # We don't use schedules, but if we do, it will be dynamic
        Resque::Scheduler.dynamic = true
        Resque::Scheduler.logger = SemanticLogger['Resque::Scheduler']
        Resque::Scheduler.logger.level = Settings.resque_scheduler.log_level.constantize
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
        return unless Resque.logger.formatter.is_a?(Resque::QuietFormatter)

        warn 'WARNING: Resque overwrote the default formatter!'

        # when this is no longer an issue remove exception in lib/gems/baw-workers/lib/baw_workers/multi_logger.rb#formatter=

        BawWorkers::Config.logger_worker.formatter = BawWorkers::MultiLogger::CustomFormatter.new
      end

      def format_result(settings)
        {
          context: resque_worker? ? 'worker' : 'rails',
          baw_workers_entry: baw_workers_entry?,
          scheduler: scheduler?,
          settings: {
            test: BawApp.test?,
            environment: BawApp.env.to_s,
            files: settings.sources,
            run_dir: BawWorkers::Config.worker_top_dir,
            is_development: BawApp.development?
          },
          redis: {
            namespace: Resque.redis.namespace.to_s,
            connection: Resque.redis.connection,
            info: Resque.info
          },
          active_job: {
            status: {
              expire_in: BawWorkers::ActiveJob::Status::Persistance.expire_values
            }
          },
          logging: {
            worker: BawWorkers::Config.logger_worker.level,
            mailer: BawWorkers::Config.logger_mailer.level,
            audio_tools: BawWorkers::Config.logger_audio_tools.level,
            resque: Resque.logger.level
          },
          yjit: lambda {
            begin
              RubyVM::YJIT.enabled?
            rescue StandardError
              'YJIT not available'
            end
          }.call
        }
      end

      def format_resque_worker(result, settings)
        is_resque_worker = resque_worker?
        result[:resque_worker] = {
          running: is_resque_worker,
          mode: baw_workers_mode(settings),
          pid_file: is_resque_worker ? ENV.fetch('PIDFILE', nil) : nil,
          queues: is_resque_worker ? ENV.fetch('QUEUES', nil) : nil,
          poll_interval: is_resque_worker ? ENV['INTERVAL'].to_f : nil
        }
        result
      end

      def log_info(result)
        BawWorkers::Config.logger_worker.warn('BawWorkers::Config') {
          result
        }
      end
    end
  end
end
