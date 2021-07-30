# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Media
      # This is the class that uses the audio tools and cache tools to cut audio segments
      # and generate spectrograms, then save them to the correct path.
      class WorkHelper
        attr_reader :audio, :spectrogram,
                    :audio_original, :audio_cache, :spectrogram_cache,
                    :temp_dir

        # Construct a new BawWorkers::Media::Process
        # @param [BawAudioTools::AudioBase] audio_base
        # @param [BawAudioTools::Spectrogram] spectrogram
        # @param [BawWorkers::Storage::AudioOriginal] audio_original
        # @param [BawWorkers::Storage::AudioCache] audio_cache
        # @param [BawWorkers::Storage::SpectrogramCache] spectrogram_cache
        # @param [FileInfo] file_info
        # @param [Logger] logger
        # @param [String] temp_dir
        def initialize(
          audio_base, spectrogram,
          audio_original, audio_cache, spectrogram_cache,
          file_info, logger, temp_dir
        )
          @audio = audio_base
          @spectrogram = spectrogram
          @audio_original = audio_original
          @audio_cache = audio_cache
          @spectrogram_cache = spectrogram_cache
          @file_info = file_info
          @logger = logger
          @temp_dir = temp_dir
        end

        def create_audio_segment(modify_parameters = {})
          cache_audio_info = @audio_cache.path_info(modify_parameters)
          target_existing = cache_audio_info[:existing]

          return target_existing if target_existing.any?

          original_audio_info = @audio_original.path_info(modify_parameters)

          check_original_paths(
            original_audio_info[:possible],
            original_audio_info[:existing],
            modify_parameters
          )

          # create in temp dir to prevent access while creating
          temp_target = temp_path(cache_audio_info[:file_names].first)

          # ensure the subdirectories exist
          FileUtils.mkpath(File.dirname(temp_target))

          # create the audio segment
          @audio.modify(
            original_audio_info[:existing].first,
            temp_target,
            modify_parameters
          )

          # copy to target dirs when finished creating temp file
          @file_info.copy_to_many(temp_target, cache_audio_info[:possible])

          # delete temp file
          FileUtils.rm(temp_target)

          # update existing paths after cutting audio
          check_cached_audio_paths(
            cache_audio_info[:file_names].first,
            original_audio_info[:existing],
            original_audio_info[:possible],
            modify_parameters
          )
        end

        # Create audio segment, with a few extra safety checks.
        # So we have a long tradition of race conditions breaking things.
        # The basic cause is both media types tend to be requested by the player at the same time.
        # So
        #   - audio requested       -> worker starts -> cached audio writing
        #   - spectrogram requested -> worker starts -> audio file exists/not empty/valid RIFF header?
        #                                               ☝️ DANGER ZONE ☝️
        # During this last stage, there a dozens of places where race conditions
        # have occurred and can cause exceptions.
        # Our solution?
        # Only use a cached audio segment IFF there are no other audio generation jobs
        # running for this segment.
        # @return [Array<(Array<string>,Boolean)] a tuple, where the first element is the path to the cache item
        #   and the second is whether or not the cache item should be deleted after use
        def create_audio_segment_for_spectrogram(modify_parameters)
          # create the cached audio segment (it must be a wav file)
          modify_parameters = modify_parameters.merge({ format: 'wav' })

          cache_audio_info = @audio_cache.path_info(modify_parameters)
          target_existing = cache_audio_info[:existing]

          # if the there are cache file and they have not been recently written
          cached_exist = target_existing.any?
          recently_written = target_existing.any?(&method(:recently_modified))

          return [target_existing, false] if cached_exist && !recently_written

          original_audio_info = @audio_original.path_info(modify_parameters)

          check_original_paths(
            original_audio_info[:possible],
            original_audio_info[:existing],
            modify_parameters
          )

          # create in temp dir to prevent access
          temp_target = temp_path(cache_audio_info[:file_names].first)

          # ensure the subdirectories exist
          FileUtils.mkpath(File.dirname(temp_target))

          # create the audio segment
          @audio.modify(
            original_audio_info[:existing].first,
            temp_target,
            modify_parameters
          )

          # Do not copy to the target dirs when finished creating temp file, file is temp only

          [[temp_target], true]
        end

        def generate_spectrogram(modify_parameters = {})
          cache_spectrogram_info = @spectrogram_cache.path_info(modify_parameters)
          target_existing = cache_spectrogram_info[:existing]

          return target_existing if target_existing.any?

          # create cached wav audio
          source_existing, delete_after_use = create_audio_segment_for_spectrogram(modify_parameters)

          # create in temp dir to prevent access while creating
          temp_target = temp_path(cache_spectrogram_info[:file_names].first)

          # create the spectrogram image in target
          # only needs the window, window_function, colour,
          # and sample rate (for calculating pixels per second)
          # everything else has already been done

          spectrogram_parameters = {
            window: modify_parameters[:window],
            window_function: modify_parameters[:window_function],
            colour: modify_parameters[:colour],
            sample_rate: modify_parameters[:sample_rate]
          }

          # ensure the subdirectories exist
          FileUtils.mkpath(File.dirname(temp_target))

          # create the spectrogram
          @spectrogram.modify(
            source_existing.first,
            temp_target,
            spectrogram_parameters
          )

          # copy to target dirs when finished creating temp file
          @file_info.copy_to_many(temp_target, cache_spectrogram_info[:possible])

          # delete temp file
          FileUtils.rm(temp_target)
          FileUtils.rm(source_existing) if delete_after_use

          # update existing paths after generating spectrogram
          check_cached_spectrogram_paths(
            cache_spectrogram_info[:file_names].first,
            source_existing,
            cache_spectrogram_info[:possible],
            modify_parameters
          )
        end

        # Was the target path modified within the last 15 seconds
        def recently_modified(path)
          # The logic here is that anything written recently could still be being written.
          # Crude, but should be effective.
          File.mtime(path) >= 15.seconds.ago
        rescue Errno::ENOENT
          # we're using this test to exclude recently modified files, so it it no
          # longer exists in a race condition scenario, it has been modified
          true
        end

        # add a random prefix to ensure uniqueness in race conditions
        def temp_path(basename)
          File.join(
            @temp_dir,
            "#{::SecureRandom.hex(7)}__#{basename}"
          )
        end

        def check_original_paths(possible, existing, modify_parameters)
          # if the original audio file(s) cannot be found, raise an exception
          return unless existing.blank?

          msg = "Could not find original audio in '#{possible}' using #{modify_parameters}."
          raise BawAudioTools::Exceptions::AudioFileNotFoundError, msg
        end

        def check_cached_audio_paths(file_name, source_existing, target_possible, modify_parameters)
          target_existing_paths = @audio_cache.existing_paths(modify_parameters)
          if target_existing_paths.blank?
            msg = "Could not create cached audio for #{file_name} from " \
                  " #{source_existing} in #{target_possible} using #{modify_parameters}."
            raise BawAudioTools::Exceptions::AudioFileNotFoundError, msg
          end
          target_existing_paths
        end

        def check_cached_spectrogram_paths(file_name, source_existing, target_possible, modify_parameters)
          target_existing_paths = @spectrogram_cache.existing_paths(modify_parameters)
          if target_existing_paths.blank?
            msg = "Could not create cached spectrogram for #{file_name} from " \
                  " #{source_existing} in #{target_possible} using #{modify_parameters}."
            raise BawAudioTools::Exceptions::SpectrogramFileNotFoundError, msg
          end
          target_existing_paths
        end
      end
    end
  end
end
