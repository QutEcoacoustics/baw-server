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

      def get_logger_files
        {
            worker: Logger.new(BawWorkers::Settings.paths.worker_log_file),
            mailer: Logger.new(BawWorkers::Settings.paths.mailer_log_file),
            audio_tools: Logger.new(BawWorkers::Settings.paths.audio_tools_log_file)
        }
      end

      def set_logger_console
        stdout_logger = Logger.new($stdout)

        self.logger_worker = MultiLogger.new(stdout_logger)
        self.logger_mailer = MultiLogger.new(stdout_logger)
        self.logger_audio_tools = MultiLogger.new(stdout_logger)
      end

      def set_logger_files
        logger_files = get_logger_files

        self.logger_worker = MultiLogger.new(logger_files[:worker])
        self.logger_mailer = MultiLogger.new(logger_files[:mailer])
        self.logger_audio_tools = MultiLogger.new(logger_files[:audio_tools])
      end

      def set_logger_console_and_file
        stdout_logger = Logger.new($stdout)
        logger_files = get_logger_files

        self.logger_worker = MultiLogger.new(stdout_logger, logger_files[:worker])
        self.logger_mailer = MultiLogger.new(stdout_logger, logger_files[:mailer])
        self.logger_audio_tools = MultiLogger.new(stdout_logger, logger_files[:audio_tools])
      end

      def set_console_to_file(stdout_file = nil, stderr_file = nil)

        stdout_log_file = stdout_file || File.expand_path(BawWorkers::Settings.resque.output_log_file)
        $stdout = File.open(stdout_log_file, 'a+')
        $stdout.sync = true

        stderr_log_file = stderr_file || File.expand_path(BawWorkers::Settings.resque.error_log_file)
        $stderr = File.open(stderr_log_file, 'a+')
        $stderr.sync = true
      end

      def set_to_console
        $stdout = STDOUT
        $stderr = STDERR
      end

      def set_rspec
        BawWorkers::Config.logger_worker.warn('BawWorkers::Config') {
          'rspec settings'
        }

        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.smtp_settings = nil

        Resque.redis = Redis.new
        Resque.redis.namespace = Settings.resque.namespace
      end

      def set_settings_source(settings_file)
        BawWorkers::Settings.configure(settings_file, 'settings')
      end

      def set_logger_levels
        # configure log levels
        self.logger_worker.level = BawWorkers::Settings.resque.log_level.constantize
        self.logger_mailer.level = BawWorkers::Settings.mailer.log_level.constantize
        self.logger_audio_tools.level = BawWorkers::Settings.audio_tools.log_level.constantize
      end

      def set_mailer
        # configure mailer
        ActionMailer::Base.logger = self.logger_mailer

        ActionMailer::Base.raise_delivery_errors = true
        ActionMailer::Base.perform_deliveries = true
        ActionMailer::Base.delivery_method = :smtp
        ActionMailer::Base.smtp_settings = BawWorkers::Settings.mailer.smtp

        ActionMailer::Base.view_paths = [
            File.expand_path(File.join(File.dirname(__FILE__), 'mail'))
        ]
      end

      def set_common
        Resque.logger = self.logger_worker

        self.audio_helper = BawAudioTools::AudioBase.from_executables(
            BawWorkers::Settings.cached_audio_defaults,
            BawWorkers::Config.logger_audio_tools,
            BawWorkers::Settings.paths.temp_dir,
            BawWorkers::Settings.audio_tools_timeout_sec,
            {
                ffmpeg: BawWorkers::Settings.audio_tools.ffmpeg_executable,
                ffprobe: BawWorkers::Settings.audio_tools.ffprobe_executable,
                mp3splt: BawWorkers::Settings.audio_tools.mp3splt_executable,
                sox: BawWorkers::Settings.audio_tools.sox_executable,
                wavpack: BawWorkers::Settings.audio_tools.wavpack_executable,
                shntool: BawWorkers::Settings.audio_tools.shntool_executable
            })

        self.spectrogram_helper = BawAudioTools::Spectrogram.from_executables(
            BawWorkers::Config.audio_helper,
            BawWorkers::Settings.audio_tools.imagemagick_convert_executable,
            BawWorkers::Settings.audio_tools.imagemagick_identify_executable,
            BawWorkers::Settings.cached_spectrogram_defaults,
            BawWorkers::Settings.paths.temp_dir)

        self.original_audio_helper = BawWorkers::Storage::AudioOriginal.new(BawWorkers::Settings.paths.original_audios)
        self.audio_cache_helper = BawWorkers::Storage::AudioCache.new(BawWorkers::Settings.paths.cached_audios)
        self.spectrogram_cache_helper = BawWorkers::Storage::SpectrogramCache.new(BawWorkers::Settings.paths.cached_spectrograms)
        self.dataset_cache_helper = BawWorkers::Storage::DatasetCache.new(BawWorkers::Settings.paths.cached_datasets)
        self.analysis_cache_helper = BawWorkers::Storage::AnalysisCache.new(BawWorkers::Settings.paths.cached_analysis_jobs)

        self.temp_dir = File.expand_path(BawWorkers::Settings.paths.temp_dir)

        self.file_info = FileInfo.new(BawWorkers::Config.audio_helper)

      end

      def set_api
        self.api_communicator = BawWorkers::ApiCommunicator.new(
            BawWorkers::Config.logger_worker,
            BawWorkers::Settings.api,
            BawWorkers::Settings.endpoints)
      end

    end
  end
end