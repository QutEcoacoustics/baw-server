# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Accumulate deployment related metadata for taggings.
      #
      # We use Site as a proxy for a deployment, and calculate deployment start and end time based on the audio
      # recordings at the site in the result set.
      class DeploymentAccumulator
        # @param force_utc_offset [Integer, nil] optional UTC offset in seconds to use instead of site timezones for
        #   all deployments accumulated by this instance.
        def initialize(force_utc_offset: nil)
          @deployments = {}

          # Store forced offsets as formatted strings so conversion can use the same stable offset for every timestamp,
          # independent of date-specific daylight saving rules.
          @force_utc_offset = force_utc_offset ? UTCOffsetString.new(ActiveSupport::TimeZone.seconds_to_utc_offset(force_utc_offset)) : nil
        end

        # +HH:MM formatted UTC offset string.
        UTCOffsetString = Data.define(:utc_offset)

        # Deployment metadata accumulated for a site.
        #
        # @!attribute [r] site
        #   @return [Site]
        # @!attribute [r] start
        #   @return [Time] earliest recording start time for the deployment.
        # @!attribute [r] end
        #   @return [Time] latest recording end time for the deployment.
        # @!attribute [r] file_public
        #   @return [Boolean] whether media files for the deployment are publicly accessible.
        # @!attribute [r] offset_or_timezone
        #   @return [UTCOffsetString, TZInfo::Timezone, ActiveSupport::TimeZone] to convert stored UTC timestamps into
        #   the export representation for the deployment.
        Deployment = Data.define(:site, :start, :end, :file_public, :offset_or_timezone) {
          # Convert a stored UTC instant into the timestamp representation used by the export.
          #
          # @param time [Time, ActiveSupport::TimeWithZone, nil] timestamp to export.
          # @return [Time, ActiveSupport::TimeWithZone, nil] timestamp converted to UTC, a fixed offset, or a site
          #   timezone, ready for Camtrap-DP ISO 8601 serialization.
          def export_time(time)
            return nil if time.blank?
            return time.utc if offset_or_timezone.nil?

            # `getlocal` preserves the instant and renders it with the requested fixed offset.
            return time.getlocal(offset_or_timezone.utc_offset) if offset_or_timezone.is_a?(UTCOffsetString)

            time.in_time_zone(offset_or_timezone)
          end
        }

        # Add a deployment for the tagging's site if it doesn't exist, or update the existing deployment's start and end
        # times if it does.
        #
        # @param tagging [Tagging] the tagging for the deployment
        # @return [Deployment] the new or updated deployment for the tagging's site
        def add_or_update(tagging)
          audio_recording = tagging.audio_event.audio_recording
          deployment = @deployments[audio_recording.site_id] || Deployment.new(
            site: audio_recording.site,
            start: nil,
            end: nil,
            file_public: audio_recording.site.public_site?,
            offset_or_timezone: @force_utc_offset || site_timezone(audio_recording.site)
          )

          @deployments[audio_recording.site_id] = deployment.with(
            start: deployment.export_time(earliest(deployment.start, audio_recording.recorded_date)),
            end: deployment.export_time(latest(deployment.end, audio_recording.recorded_end_date))
          )
        end

        def earliest(*times) = times.compact.min
        def latest(*times) = times.compact.max

        def values = @deployments.values

        private

        # @param site [Site] site whose timezone should be used for export timestamps.
        # @return [TZInfo::Timezone, ActiveSupport::TimeZone] timezone of site or UTC fallback for nil or zero-offset timezones.
        def site_timezone(site)
          return ActiveSupport::TimeZone['UTC'] if site.timezone.blank? || site.timezone[:utc_total_offset].zero?

          TimeZoneHelper.tzinfo_class(site.tzinfo_tz)
        end
      end
    end
  end
end
