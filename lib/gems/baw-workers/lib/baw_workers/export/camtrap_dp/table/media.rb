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
          def self.mapping(audio_recording, file_public)
            ar = audio_recording
            recorded_date = ar.recorded_date

            file_path = Api::UrlHelpers::Base.new.audio_recording_media_original_url(audio_recording_id: ar.id)

            # required Date and time at which the media file was recorded. Formatted as an ISO 8601 string with timezone
            # designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
            if ar.site.timezone.blank? || ar.site.timezone[:utc_total_offset].zero?
              recorded_date&.utc&.iso8601
            else
              timezone = TimeZoneHelper.tzinfo_class(ar.site.tzinfo_tz)
              recorded_date.in_time_zone(timezone).iso8601
            end => timestamp

            # ? is this correct? what happens if doesn't calculate valid enum value, just nil instead?
            bit_depth = (ar.bit_rate_bps.to_f / (ar.channels * ar.sample_rate_hertz))
            bit_depth = nil unless bit_depth.in?([8, 16, 24, 32])

            Media.new(
              mediaID: ar.id, # required
              deploymentID: ar.site_id, # required
              captureMethod: nil,
              timestamp: timestamp,
              duration: ar.duration_seconds,
              filePath: file_path, # required
              filePublic: file_public, # required
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
