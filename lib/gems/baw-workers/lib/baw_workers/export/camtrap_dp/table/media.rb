module BawWorkers
  module Export
    module CamtrapDp
      module Table
        # Represents a row in the `media` table of the Camtrap Data Package.
        #
        # Attributes are defined in schema order (required for CSV validation).
        class Media < BawWorkers::Dry::OrderedStruct
          Types = BawWorkers::Dry::Types

          attribute :mediaID, Types::ID
          attribute :deploymentID, Types::ID
          attribute? :captureMethod, Types::String.enum('activityDetection', 'continuous', 'recordingSchedule').optional
          attribute :timestamp, Types::UtcTimeMicroseconds
          attribute? :duration, Types::Decimal.optional
          attribute :filePath, Types::String
          attribute :filePublic, Types::Bool
          attribute? :fileName, Types::String.optional
          attribute :fileMediatype, Types::String
          attribute? :exifData, Types::Hash.optional
          attribute? :bitDepth, Types::Integer.enum(8, 16, 24, 32).optional
          attribute? :samplingFrequency, Types::SampleRate.optional
          attribute? :gain, Types::Integer.optional # in dB
          attribute? :channels, Types::Channel.optional
          attribute? :favorite, Types::Bool.optional
          attribute? :mediaComments, Types::String.optional

          # @param audio_recording [AudioRecording] the audio recording to map
          # @param deployment [DeploymentAccumulator::Deployment] the deployment metadata for the audio recording;
          #   its `export_time` method applies the forced UTC offset, site timezone, or UTC fallback.
          # @return [Media] the media struct with the mapped values
          def self.mapping(audio_recording, deployment)
            # Manually set the site association cache on the audio recording to avoid a database query when calling `friendly_name`.
            audio_recording = audio_recording.tap { |ar| ar.association(:site).target = deployment.site }

            file_path = Api::UrlHelpers::Base.new.audio_recording_media_original_url(audio_recording_id: audio_recording.id)

            # ? Is this calculation correct? There are many cases in the database where this calculation doesn't result
            # ? in their valid enum values. And in that case, we just have to return nil?
            # ? Alternatively, we also emit our own bit_rate_bps field?
            bit_depth = (audio_recording.bit_rate_bps.to_f / (audio_recording.channels * audio_recording.sample_rate_hertz))
            bit_depth = nil unless bit_depth.in?([8, 16, 24, 32])

            Media.new(
              mediaID: audio_recording.id,
              deploymentID: deployment.site.id,
              captureMethod: nil,
              timestamp: deployment.export_time(audio_recording.recorded_date),
              duration: audio_recording.duration_seconds,
              filePath: file_path,
              filePublic: deployment.file_public,
              fileName: audio_recording.friendly_name,
              fileMediatype: audio_recording.media_type,
              exifData: nil,
              bitDepth: bit_depth,
              samplingFrequency: audio_recording.sample_rate_hertz,
              gain: nil,
              channels: audio_recording.channels,
              favorite: nil,
              mediaComments: audio_recording.notes.to_s
            )
          end
        end
      end
    end
  end
end
