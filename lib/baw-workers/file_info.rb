module BawWorkers
  # Helpers to get info from files.
  class FileInfo

    def initialize(logger, audio_base)
      @logger = logger
      @audio = audio_base
    end

    # Get info for an existing file.
    # @param [String] source
    # @return [Hash] information about an existing file
    def audio_info(source)

      # based on how harvester gets file hash.
      generated_file_hash = 'SHA256::' + generate_hash(source).hexdigest

      # integrity
      integrity_check = @audio.integrity_check(source)

      # get file info using ffmpeg
      info = @audio.info(source)

      {
          file: source,
          extension: File.extname(source).delete('.'),
          errors: integrity_check.errors,
          file_hash: generated_file_hash,
          media_type: info[:media_type],
          sample_rate_hertz: info[:sample_rate],
          duration_seconds: info[:duration_seconds].to_f.round(3),
          bit_rate_bps: info[:bit_rate_bps],
          data_length_bytes: info[:data_length_bytes],
          channels: info[:channels],
      }
    end

    # @param [string] source
    # @return [Digest::SHA256] Digest::SHA256 of file
    def generate_hash(source)
      incr_hash = Digest::SHA256.new

      File.open(source) do |file|
        buffer = ''

        # Read the file 512 bytes at a time
        until file.eof
          file.read(512, buffer)
          incr_hash.update(buffer)
        end
      end

      incr_hash
    end

    # Copy one source file to many destinations.
    # @param [String] source
    # @param [Array<String>] targets
    def copy_to_many(source, targets)
      targets.each do |target|

        # ensure the subdirectories exist
        FileUtils.mkpath(File.dirname(target))

        # copy file to other locations
        FileUtils.cp(source, target)
      end
    end

    def copy_and_rename(source_file, create_response_json, file_info_hash)
      dest_paths = []

      # construct paths to move file
      dest_paths = construct_destinations(create_response_json, file_info_hash)
      @logger.log Logger::DEBUG, "Copying source file to #{dest_paths}."

      dest_paths.each do |dest_path|
        @fs.copy_file(source_file, dest_path)
      end

      # delete file once it is copied to all destinations
      source_size = File.size(source_file)
      if dest_paths.all? { |file| File.exists?(file) && File.file?(file) && File.size(file) == source_size }
        @logger.log Logger::INFO, "Source file #{source_file} was copied successfully to all destinations, renaming source file."
        renamed_source_file = source_file + '.completed'
        File.rename(source_file, renamed_source_file)
        if File.exists?(source_file)
          @logger.log Logger::WARN, "Source file #{source_file} was not renamed."
        elsif File.exists?(renamed_source_file)
          @logger.log Logger::INFO, "Source file #{source_file} was successfully renamed to #{renamed_source_file}."
        end
      else
        @logger.log Logger::WARN, "Source file #{source_file} was not copied to all destinations #{dest_paths}."
      end
    end

    def construct_destinations(create_response, file_info_hash)
      datetime = Time.zone.parse(file_info_hash[:recorded_date])

      #original_file_name = @media_cacher.original_audio_file_names(original_file_name_hash)
      original_file_name = @media_cacher.cache.original_audio.file_name_utc(
          create_response['uuid'],
          datetime,
          file_info_hash[:extension]
      )

      @media_cacher.cache.possible_storage_paths(@media_cacher.cache.original_audio, original_file_name)
    end

    # Get basic file info.
    # @param [string] source
    # @return [Hash]
    def basic(source)
      {
          file_path: File.expand_path(source),
          file_name: File.basename(source),
          extension: File.extname(source).reverse.chomp('.').reverse,
          access_time: File.atime(source),
          change_time: File.ctime(source),
          modified_time: File.mtime(source),
          data_length_bytes: File.size(source)
      }
    end


  end
end