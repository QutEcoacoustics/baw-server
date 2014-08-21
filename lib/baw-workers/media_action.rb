module BawWorkers
  # Media Action for cutting audio files and generating spectrograms.
  class MediaAction

    # Ensure that there is only one job with the same payload per queue.
    # The default method to create a job ID from these parameters is to
    # do some normalization on the payload and then md5'ing it
    include Resque::Plugins::UniqueJob

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
    def self.lock_after_execution_period
      30
    end

    # Get the queue for this action. Used by `resque`.
    # @return [Symbol] The queue.
    def self.queue
      BawWorkers::Settings.resque.queues.media
    end

    # Enqueue a media processing request.
    # @param [Symbol] media_type
    # @param [Hash] media_request_params
    def self.enqueue(media_type, media_request_params)
      validate(media_type, media_request_params)
      Resque.enqueue(MediaAction, media_type, media_request_params)
    end

    # Get the available media types this action can create.
    # @return [Symbol] The available media types.
    def self.valid_media_types
      [:audio, :spectrogram]
    end

    # Perform work. Used by `resque`.
    # @param [Symbol] media_type
    # @param [Hash] media_request_params
    # @return [Array<String>] target existing paths
    def self.perform(media_type, media_request_params)
      target_existing_paths = make_media_request(media_type, media_request_params)
      target_existing_paths
    end

    # Create specified media type by applying media request params.
    # @param [Symbol] media_type
    # @param [Hash] media_request_params
    # @return [Array<String>] target existing paths
    def self.make_media_request(media_type, media_request_params)
      validate(media_type, media_request_params)
      media_cache_tool = BawWorkers::Settings.media_cache_tool
      target_existing_paths = []
      if media_type == :audio
        target_existing_paths = media_cache_tool.create_audio_segment(media_request_params)
      elsif media_type == :spectrogram
        target_existing_paths = media_cache_tool.generate_spectrogram(media_request_params)
      end

      target_existing_paths
    end

    private

    def self.validate(media_type, media_request_params)
      fail ArgumentError, "Media type (#{media_type.inspect}) was not valid (#{valid_media_types})." unless valid_media_types.include?(media_type)
      fail ArgumentError, "Media request params was not a hash (#{media_request_params.inspect})" unless media_request_params.is_a?(Hash)
    end

  end
end