module BawWorkers
  module Export
    module CamtrapDp
      module Table
        # Represents a row in the `media` table of the Camtrap Data Package.
        #
        # Attributes are defined in schema order (required for CSV validation).
        class Media < BawWorkers::Dry::OrderedStruct
          Types = BawWorkers::Dry::Types

          attribute :mediaID, Types::Coercible::String
          attribute :deploymentID, Types::Coercible::String
          attribute? :captureMethod, Types::String.enum('activityDetection', 'continuous', 'recordingSchedule')
          attribute :timestamp, Types::UtcTimeMicroseconds
          attribute? :duration, Types::Decimal
          attribute :filePath, Types::String
          attribute :filePublic, Types::Bool
          attribute? :fileName, Types::String
          attribute :fileMediatype, Types::String
          attribute? :exifData, Types::Hash
          attribute? :bitDepth, Types::Integer.enum(8, 16, 24, 32)
          attribute? :samplingFrequency, Types::SampleRate
          attribute? :gain, Types::Integer
          attribute? :channels, Types::Channel
          attribute? :favorite, Types::Bool
          attribute? :mediaComments, Types::String

          # @param audio_recording [AudioRecording] the audio recording to map
          # @param deployment [DeploymentAccumulator::Deployment] the deployment metadata for the audio recording;
          #   its `ensure_timezone` method applies the forced UTC offset, site timezone, or UTC fallback.
          # @return [Media] the media struct with the mapped values
          def self.mapping(audio_recording, deployment)
            file_path = Api::UrlHelpers.audio_recording_media_original_url(audio_recording_id: audio_recording.id)

            # TODO: add bitDepth when closed: https://github.com/QutEcoacoustics/baw-server/issues/1020
            attributes = {
              mediaID: audio_recording.global_identifier,
              deploymentID: deployment.site.global_identifier,
              # captureMethod:,
              timestamp: deployment.ensure_timezone(audio_recording.recorded_date),
              duration: audio_recording.duration_seconds,
              filePath: file_path,
              filePublic: deployment.file_public,
              fileName: audio_recording.friendly_name,
              fileMediatype: audio_recording.media_type,
              # exifData:,
              # bitDepth:,
              samplingFrequency: audio_recording.sample_rate_hertz,
              # gain:,
              channels: audio_recording.channels
              # favorite:,
              # mediaComments:
            }.compact

            Media.new(attributes)
          end
        end
      end
    end
  end
end
