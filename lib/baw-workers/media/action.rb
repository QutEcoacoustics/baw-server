module BawWorkers
  module Media
    # Action for cutting audio files and generating spectrograms.
    class Action

      include BawWorkers::Common

      # Ensure that there is only one job with the same payload per queue.
      # The default method to create a job ID from these parameters is to
      # do some normalization on the payload and then md5'ing it
      include Resque::Plugins::UniqueJob

      # a set of keys starting with 'stats:jobs:queue_name' inside your Resque redis namespace
      # Jobs performed
      # Jobs enqueued
      # Jobs failed
      # Duration of last x jobs completed
      # Average job duration over last 100 jobs completed
      # Longest job duration over last 100 jobs completed
      # Jobs enqueued as timeseries data (minute, hour, day)
      # Jobs performed as timeseries data (minute, hour, day)
      extend Resque::Plugins::JobStats

      class << self

        # By default, lock_after_execution_period is 0 and enqueued? becomes
        # false as soon as the job is being worked on.
        # The lock_after_execution_period setting can be used to delay when
        # the unique job key is deleted (i.e. when enqueued? becomes false).
        # For example, if you have a long-running unique job that takes around
        # 10 seconds, and you don't want to requeue another job until you are
        # sure it is done, you could set lock_after_execution_period = 20.
        # Or if you never want to run a long running job more than once per
        # minute, set lock_after_execution_period = 60.
        # @return [Fixnum]
        def lock_after_execution_period
          30
        end

        # Get the queue for this action. Used by Resque.
        # @return [Symbol] The queue.
        def queue
          BawWorkers::Settings.resque.queues.media
        end

        # Enqueue a media processing request.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        def enqueue(media_type, media_request_params)
          media_type_sym, params_sym = validate(media_type, media_request_params)
          Resque.enqueue(BawWorkers::Media::Action, media_type_sym, params_sym)
          BawWorkers::Settings.logger.info(self.name) {
            "Enqueued #{media_type} from MediaAction #{media_request_params}."
          }
        end

        # Get the available media types this action can create.
        # @return [Symbol] The available media types.
        def valid_media_types
          [:audio, :spectrogram]
        end

        # Perform work. Used by Resque.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def perform(media_type, media_request_params)
          media_type_sym, params_sym = validate(media_type, media_request_params)
          make_media_request(media_type_sym, params_sym)
        end

        # Create specified media type by applying media request params.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def make_media_request(media_type, media_request_params)
          media_type_sym, params_sym = validate(media_type, media_request_params)

          params_sym[:datetime_with_offset] = check_datetime(params_sym[:datetime_with_offset])

          logger = BawWorkers::Settings.logger

          helper = BawWorkers::Media::WorkHelper.new(
              BawWorkers::Settings.audio_helper,
              BawWorkers::Settings.spectrogram_helper,
              BawWorkers::Settings.original_audio_helper,
              BawWorkers::Settings.audio_cache_helper,
              BawWorkers::Settings.spectrogram_cache_helper,
              BawWorkers::FileInfo.new(logger, BawWorkers::Settings.audio_helper),
              BawWorkers::Settings.logger,
              BawWorkers::Settings.paths.temp_dir
          )

          target_existing_paths = []
          case media_type_sym
            when :audio
              target_existing_paths = helper.create_audio_segment(params_sym)
            when :spectrogram
              target_existing_paths = helper.generate_spectrogram(params_sym)
            else
              validate_contains(media_type_sym, valid_media_types)
          end

          BawWorkers::Settings.logger.info(self.name) {
            "Created cache files #{media_type}: #{target_existing_paths}."
          }

          target_existing_paths
        end

        private

        def validate(media_type, media_request_params)
          validate_hash(media_request_params)
          media_type_sym, params_sym = symbolize(media_type, media_request_params)
          validate_contains(media_type_sym, valid_media_types)
          [media_type_sym, params_sym]
        end
      end
    end
  end
end