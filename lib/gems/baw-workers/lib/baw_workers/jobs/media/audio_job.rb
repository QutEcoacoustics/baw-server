# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Media
      # Cuts audio files and generates spectrograms.
      class AudioJob < MediaJob
        queue_as Settings.actions.media.queue
        perform_expects ::BawWorkers::Models::AudioRequest

        # Perform work. Used by Resque.
        # @param [::BawWorkers::Models::AudioRequest] payload
        # @return [void]
        def perform(payload)
          logger.measure_info('Processing audio', payload: payload) do
            action_validate(payload)

            make_media_request(payload)
          end
        end

        # Produces a sensible name for this payload.
        # Should be unique but does not need to be. Has no operational effect.
        # This value is only used when the status is updated by resque:status.
        def name
          mrp = arguments&.first
          @name ||= "Audio request: [#{mrp&.try(:start_offset)}-#{mrp&.try(:end_offset)}), format=#{mrp&.try(:format)}"
        end

        def create_job_id
          # duplicate jobs should be detected
          ::BawWorkers::ActiveJob::Identity::Generators.generate_hash_id(self, 'audio_job')
        end

        private

        # Create specified media type by applying media request params.
        # @param [::BawWorkers::Models::AudioRequest] media_request_params
        # @return [Array<String>] target existing paths
        def make_media_request(media_request_params)
          params_sym = media_request_params.to_h
          params_sym[:datetime_with_offset] =
            BawWorkers::Validation.normalise_datetime(params_sym[:datetime_with_offset])

          target_existing_paths = action_helper.create_audio_segment(params_sym)

          result = redis_cache_upload(target_existing_paths)
          logger.info do
            "Created cache files: #{target_existing_paths}. Uploaded to redis?: #{result}"
          end

          target_existing_paths
        end

        # @param [Payload] payload
        def action_validate(payload)
          return if payload.is_a?(BawWorkers::Models::AudioRequest)

          raise ArgumentError, 'parameters for audio request were not the correct type'
        end
      end
    end
  end
end
