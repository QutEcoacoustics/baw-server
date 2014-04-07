module BawWorkers
  class AudioFileCheckAction

    def self.queue
      Settings.resque.media_request_queue.map { |queue| queue.to_sym }
    end

    # Perform action. Use audio_recordings.to_a.map(&:serializable_hash). Add 'original_extension'.
    # @param [Hash] audio_recording_hash
    def self.perform(audio_recording_hash)

      recorded_date = Time.zone.parse(audio_recording_hash['recorded_date'])
      uuid = audio_recording_hash['uuid']
      extension = audio_recording_hash['original_extension']
      file_hash = audio_recording_hash['file_hash']
      data_length_bytes = audio_recording_hash['data_length_bytes']
      duration_seconds = audio_recording_hash['duration_seconds']

      @media_cacher = BawAudioTools::MediaCacher.new(Settings.paths.temp_files)

      original_file_name = @media_cacher.cache.original_audio.file_name_utc(uuid, recorded_date, extension)

      possible_storage_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.original_audio, original_file_name)
      existing_storage_paths = @media_cacher.cache.existing_storage_paths(@media_cacher.cache.original_audio, original_file_name)

      if existing_storage_paths.blank?
        msg = "Could not find original audio file #{original_file_name} in #{possible_storage_paths}."
        raise BawAudioTools::Exceptions::AudioFileNotFoundError, msg
      end

      existing_storage_paths.each do |file_full_path|
        file_info = @media_cacher.audio.info(file_full_path)
        # TODO: compare file info with stored info, any differences should be updated in database?
      end

    end

  end
end