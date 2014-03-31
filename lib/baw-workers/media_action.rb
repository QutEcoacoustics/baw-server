module BawWorkers
  class MediaAction

    def self.queue
      Settings.resque.media_request_queue.map { |queue| queue.to_sym }
    end

    def self.perform(media_request_type, modify_parameters)
      # queue and paths should match e.g. Settings.resque.queue_prefix = production
      # Settings.paths.original_audios = /production/original_audio
      @media_cacher = BawAudioTools::MediaCacher.new(Settings.paths.temp_files)

      Resque.redis = Settings.resque.connection

      if media_request_type == 'cache_audio'
        @media_cacher.create_audio_segment(modify_parameters)
      elsif media_request_type == 'cache_spectrogram'
        @media_cacher.generate_spectrogram(modify_parameters)
      end
    end

  end
end