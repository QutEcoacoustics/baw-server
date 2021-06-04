# frozen_string_literal: true

module BawWorkers
  module Media
    # Cuts audio files and generates spectrograms.
    class Action < BawWorkers::ActionBase
      class << self
        # Get the queue for this action. Used by Resque. Overrides resque-status class method.
        # @return [Symbol] The queue.
        def queue
          Settings.actions.media.queue
        end

        # Perform work. Used by Resque.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def action_perform(media_type, media_request_params)
          BawWorkers::Config.logger_worker.info(name) do
            "Started media #{media_type} using '#{media_request_params}'."
          end

          begin
            media_type_sym, params_sym = action_validate(media_type, media_request_params)
            result = make_media_request(media_type_sym, params_sym)
          rescue StandardError => e
            BawWorkers::Config.logger_worker.error(name) { e }
            BawWorkers::Mail::Mailer.send_worker_error_email(
              BawWorkers::Media::Action,
              { media_type: media_type, media_request_params: media_request_params },
              queue,
              e
            )
            raise e
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Completed media with result '#{result}'."
          end

          result
        end

        # Enqueue a media processing request.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [void]
        def action_enqueue(media_type, media_request_params)
          media_type_sym, params_sym = action_validate(media_type, media_request_params)
          #Resque.enqueue(BawWorkers::Media::Action, media_type_sym, params_sym)
          result = BawWorkers::Media::Action.create(media_type: media_type_sym, media_request_params: params_sym)
          BawWorkers::Config.logger_worker.info(name) do
            "Job enqueue returned '#{result}' using type #{media_type} with #{media_request_params}."
          end
          result
        end

        # Get the available media types this action can create.
        # @return [Array<Symbol>] The available media types.
        def valid_media_types
          [:audio, :spectrogram]
        end

        # Get helper class instance.
        # @return [BawWorkers::Media::WorkHelper]
        def action_helper
          BawWorkers::Media::WorkHelper.new(
            BawWorkers::Config.audio_helper,
            BawWorkers::Config.spectrogram_helper,
            BawWorkers::Config.original_audio_helper,
            BawWorkers::Config.audio_cache_helper,
            BawWorkers::Config.spectrogram_cache_helper,
            BawWorkers::Config.file_info,
            BawWorkers::Config.logger_worker,
            BawWorkers::Config.temp_dir
          )
        end

        # Create specified media type by applying media request params.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Array<String>] target existing paths
        def make_media_request(media_type, media_request_params)
          media_type_sym, params_sym = action_validate(media_type, media_request_params)

          params_sym[:datetime_with_offset] = BawWorkers::Validation.normalise_datetime(params_sym[:datetime_with_offset])

          target_existing_paths = []
          case media_type_sym
          when :audio
            target_existing_paths = action_helper.create_audio_segment(params_sym)
          when :spectrogram
            target_existing_paths = action_helper.generate_spectrogram(params_sym)
          else
            BawWorkers::Validation.check_hash_contains(media_type_sym, valid_media_types)
          end

          BawWorkers::Config.logger_worker.info(name) do
            "Created cache files #{media_type}: #{target_existing_paths}."
          end

          target_existing_paths
        end

        def action_validate(media_type, media_request_params)
          BawWorkers::Validation.check_hash(media_request_params)
          media_type_sym = media_type.to_sym
          params_sym = BawWorkers::Validation.deep_symbolize_keys(media_request_params)
          BawWorkers::Validation.check_hash_contains(media_type_sym, valid_media_types)
          [media_type_sym, params_sym]
        end

        # Get a Resque::Status hash for if a media job has a matching payload.
        # @param [Symbol] media_type
        # @param [Hash] media_request_params
        # @return [Resque::Plugins::Status::Hash] status
        def get_job_status(media_type, media_request_params)
          media_type_sym, params_sym = action_validate(media_type, media_request_params)
          payload = { media_type: media_type_sym, media_request_params: params_sym }
          BawWorkers::ResqueApi.status(BawWorkers::Media::Action, payload)
        end
      end

      #
      # Instance methods
      #

      # List of keys to pull out of options/payload hash.
      # @return [Array<String>]
      def perform_options_keys
        ['media_type', 'media_request_params']
      end

      # Produces a sensible name for this payload.
      # Should be unique but does not need to be. Has no operational effect.
      # This value is only used when the status is updated by resque:status.
      def name
        mrp = @options['media_request_params']
        "Media request: #{@options['media_type']}, [#{mrp['start_offset']}-#{mrp['end_offset']}), format=#{mrp['format']}"
      end
    end
  end
end
