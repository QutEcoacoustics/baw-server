module BawWorkers
  module Export
    module CamtrapDp
      class Media < ::Dry::Struct
        Types = BawWorkers::Dry::Types
        attribute :mediaID, Types::ID
        attribute :deploymentID, Types::ID
        attribute :fileMediatype, Types::String
        attribute :filePublic, Types::Bool
        attribute :filePath, Types::String
        attribute :timestamp, ::BawApp::Types::UtcTime
        attribute? :bitDepth, Types::Integer.enum(8, 16, 24, 32).optional
        attribute? :captureMethod,
          Types::String.enum('activityDetection', 'continuous', 'recordingSchedule').optional
        attribute? :channels, Types::Channel.optional
        attribute? :duration, Types::Decimal.optional
        attribute? :exifData, Types::Hash.optional
        attribute? :favorite, Types::Bool.optional
        attribute? :fileName, Types::String.optional
        attribute? :gain, Types::Integer.optional # in dB
        attribute? :mediaComments, Types::String.optional
        attribute? :samplingFrequency, Types::SampleRate.optional

        # This is the mapping of our data onto the schema - how to get the values for those fields
        def self.mapping(audio_recording, file_public)
          ar = audio_recording
          # ar.original_file_paths ? returns an array
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

          # ? is this correct? what happens if doesn't give valid enum value, just nil instead?
          bit_depth = (ar.bit_rate_bps.to_f / (ar.channels * ar.sample_rate_hertz))
          bit_depth = nil unless bit_depth.in?([8, 16, 24, 32])

          Media.new(
            mediaID: ar.id, # required
            deploymentID: ar.site_id, # required
            fileMediatype: ar.media_type, # required
            filePublic: file_public, # required
            filePath: file_path, # required
            timestamp: timestamp,
            bitDepth: bit_depth, # optional
            captureMethod: nil,
            channels: ar.channels,
            duration: ar.duration_seconds,
            exifData: nil,
            favorite: nil,
            fileName: ar.friendly_name,
            gain: nil,
            mediaComments: ar.notes.to_s,
            samplingFrequency: ar.sample_rate_hertz
          )
        end
      end
    end
  end
end
