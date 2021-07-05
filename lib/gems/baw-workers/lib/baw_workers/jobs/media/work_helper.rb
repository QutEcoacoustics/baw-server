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

          if target_existing.blank?
            original_audio_info = @audio_original.path_info(modify_parameters)

            check_original_paths(
              original_audio_info[:possible],
              original_audio_info[:existing],
              modify_parameters
            )

            # create in temp dir to prevent access while creating
            temp_target_existing = File.join(@temp_dir, cache_audio_info[:file_names].first)

            # ensure the subdirectories exist
            FileUtils.mkpath(File.dirname(temp_target_existing))

            # create the audio segment
            @audio.modify(
              original_audio_info[:existing].first,
              temp_target_existing,
              modify_parameters
            )

            # copy to target dirs when finished creating temp file
            @file_info.copy_to_many(temp_target_existing, cache_audio_info[:possible])

            # delete temp file
            FileUtils.rm(temp_target_existing)

            # update existing paths after cutting audio
            target_existing = check_cached_audio_paths(
              cache_audio_info[:file_names].first,
              original_audio_info[:existing],
              original_audio_info[:possible],
              modify_parameters
            )
          end

          target_existing
        end

        def generate_spectrogram(modify_parameters = {})
          cache_spectrogram_info = @spectrogram_cache.path_info(modify_parameters)
          target_existing = cache_spectrogram_info[:existing]

          if target_existing.blank?
            # create the cached audio segment (it must be a wav file)
            # merge does not include nested hashes, but will actually create a new hash
            # http://thingsaaronmade.com/blog/ruby-shallow-copy-surprise.html
            cached_wav_audio_parameters = {}.merge(modify_parameters)
            cached_wav_audio_parameters[:format] = 'wav'

            # create cached wav audio
            source_existing = create_audio_segment(cached_wav_audio_parameters)

            # create in temp dir to prevent access while creating
            temp_target_existing = File.join(@temp_dir, cache_spectrogram_info[:file_names].first)

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
            FileUtils.mkpath(File.dirname(temp_target_existing))

            # create the spectrogram
            @spectrogram.modify(
              source_existing.first,
              temp_target_existing,
              spectrogram_parameters
            )

            # copy to target dirs when finished creating temp file
            @file_info.copy_to_many(temp_target_existing, cache_spectrogram_info[:possible])

            # delete temp file
            FileUtils.rm(temp_target_existing)

            # update existing paths after generating spectrogram
            target_existing = check_cached_spectrogram_paths(
              cache_spectrogram_info[:file_names].first,
              source_existing,
              cache_spectrogram_info[:possible],
              modify_parameters
            )
          end

          target_existing
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
