# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Media
      # Cuts audio files and generates spectrograms.
      class SpectrogramJob < MediaJob
        queue_as Settings.actions.media.queue
        perform_expects ::BawWorkers::Models::SpectrogramRequest

        # Perform work. Used by Resque.
        # @param [::BawWorkers::Models::SpectrogramRequest] payload
        # @return [void]
        def perform(payload)
          logger.measure_info('Processing media', payload: payload) do
            action_validate(payload)

            make_media_request(payload)
          end
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          mrp = arguments&.first
          @name ||= "Spectrogram request: [#{mrp&.try(:start_offset)}-#{mrp&.try(:end_offset)}), format=#{mrp&.try(:format)}"
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'spectrogram_job')
        end

        private

        # Create specified media type by applying media request params.
        # @param [Symbol] media_type
        # @param [::BawWorkers::Models::SpectrogramRequest] media_request_params
        # @return [Array<String>] target existing paths
        def make_media_request(media_request_params)
          params_sym = media_request_params.to_h
          params_sym[:datetime_with_offset] =
            BawWorkers::Validation.normalise_datetime(params_sym[:datetime_with_offset])

          target_existing_paths = action_helper.generate_spectrogram(params_sym)

          result = redis_cache_upload(target_existing_paths)
          logger.info do
            "Created cache files: #{target_existing_paths}. Uploaded to redis?: #{result}"
          end

          target_existing_paths
        end

        # @param [Payload] payload
        def action_validate(payload)
          return if payload.is_a?(BawWorkers::Models::SpectrogramRequest)

          raise ArgumentError, 'parameters for spectrogram request were not the correct type'
        end
      end
    end
  end
end
