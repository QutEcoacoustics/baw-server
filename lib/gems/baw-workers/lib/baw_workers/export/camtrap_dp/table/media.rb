module BawWorkers
  module Export
    module CamtrapDp
      module Table
        class Media < ::Dry::Struct
          Types = BawWorkers::Dry::Types
          attribute :mediaID, Types::ID
          attribute :deploymentID, Types::ID
          attribute? :captureMethod, Types::String.enum('activityDetection', 'continuous', 'recordingSchedule').optional
          attribute :timestamp, Types::UtcTimeMicros
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

          # This is the mapping of our data onto the schema - how to get the values for those fields
          # @param audio_recording [AudioRecording] the audio recording to map
          # @param deployment [DeploymentAccumulator::Deployment] the deployment for the audio recording
          # @return [Media] the mapped media object
          def self.mapping(audio_recording, deployment)
            # AudioRecording#friendly_name uses `site` which queries the database for site on every audio recording processed.
            # But we already have the site in `deployment`, so we can set the association cache to prevent the query.
            ar = audio_recording.tap { |ar| ar.association(:site).target = deployment.site }

            file_path = Api::UrlHelpers::Base.new.audio_recording_media_original_url(audio_recording_id: ar.id)

            # Required Date and time at which the media file was recorded. Formatted as an ISO 8601 string with timezone
            # designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
            if deployment.site.timezone.blank? || deployment.site.timezone[:utc_total_offset].zero?
              ar.recorded_date&.utc&.iso8601
            else
              timezone = TimeZoneHelper.tzinfo_class(deployment.site.tzinfo_tz)
              ar.recorded_date.in_time_zone(timezone).iso8601
            end => timestamp

            # Is this calculation correct? There are many cases in the database where the calculation doesn't result in a valid enum value.
            # And in that case, just return nil? Alternatively, we also emit our own bit_rate_bps field?
            bit_depth = (ar.bit_rate_bps.to_f / (ar.channels * ar.sample_rate_hertz))
            bit_depth = nil unless bit_depth.in?([8, 16, 24, 32])

            Media.new(
              mediaID: ar.id, # required
              deploymentID: deployment.site.id, # required
              captureMethod: nil,
              timestamp: timestamp,
              duration: ar.duration_seconds,
              filePath: file_path, # required
              filePublic: deployment.file_public, # required
              fileName: ar.friendly_name,
              fileMediatype: ar.media_type, # required
              exifData: nil,
              bitDepth: bit_depth, # optional
              samplingFrequency: ar.sample_rate_hertz,
              gain: nil,
              channels: ar.channels,
              favorite: nil,
              mediaComments: ar.notes.to_s
            )
          end
        end
      end
    end
  end
end
