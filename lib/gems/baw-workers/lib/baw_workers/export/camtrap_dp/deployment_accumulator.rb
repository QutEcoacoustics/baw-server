# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Accumulate deployment related metadata for taggings.
      #
      # We use Site as a proxy for a deployment, and calculate deployment start and end time based on all audio
      # recordings at the site.
      class DeploymentAccumulator
        # The caller can provide a timezone override. If provided, all timestamps in the export will use this timezone.
        # You can even provide a custom timezone, e.g.: `ActiveSupport::TimeZone.create('Fixed', 600, TZInfo::Timezone.get('GMT'))`
        #
        # @param forced_timezone [ActiveSupport::TimeZone, TZInfo::Timezone, nil] optional timezone
        def initialize(forced_timezone: nil)
          @deployments = {}

          if forced_timezone && !(forced_timezone.is_a?(ActiveSupport::TimeZone) || forced_timezone.is_a?(TZInfo::Timezone))
            raise ArgumentError, "forced_timezone: got #{forced_timezone.class}, expected ActiveSupport::TimeZone or TZInfo::Timezone"
          end

          @forced_timezone = forced_timezone
        end

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
        # @!attribute [r] timezone
        #   @return [TZInfo::Timezone, ActiveSupport::TimeZone] the timezone to use for timestamps in this deployment
        Deployment = Data.define(:site, :start, :end, :file_public, :timezone) {
          # Ensures all times in a deployment are in a uniform Timezone for exporting.
          #
          # @param time [Time, ActiveSupport::TimeWithZone, nil] timestamp to export.
          # @return [Time, ActiveSupport::TimeWithZone, nil] timestamp converted to the deployment's timezone,
          #   ready for Camtrap-DP ISO 8601 serialization.
          def ensure_timezone(time)
            return nil if time.blank?

            # return time.utc if timezone.nil?

            time.in_time_zone(timezone)
          end
        }

        # Add a deployment for the tagging's site if it doesn't exist. Initialize the deployment's timezone based on the
        # site's timezone, unless a forced_timezone was provided to the accumulator.
        #
        # This isn't a problem now, but it's worth noting: deployments are keyed by site_id, and site is cached the
        # first time seen. So when using find_each in batches, the same site from a later batch will have a different
        # object_id than the cached site object.
        #
        # @param tagging [Tagging] the tagging for the deployment
        # @return [Deployment] the new or updated deployment for the tagging's site
        def add_or_update(tagging)
          audio_recording = tagging.audio_event.audio_recording
          @deployments[audio_recording.site_id] ||= build_deployment(audio_recording.site)
        end

        def values = @deployments.values

        private

        def build_deployment(site)
          timezone = @forced_timezone || site_timezone(site)
          recording_bounds = AudioRecording.pick_hash({
            start: AudioRecording.arel_table[:recorded_date].minimum,
            end: AudioRecording.arel_recorded_end_date.maximum
          }, scope: site.audio_recordings)

          Deployment.new(
            site: site,
            start: recording_bounds[:start]&.in_time_zone(timezone),
            end: recording_bounds[:end]&.in_time_zone(timezone),
            file_public: site.public_site?,
            timezone: timezone
          )
        end

        # @param site [Site] site whose timezone should be used for export timestamps.
        # @return [TZInfo::Timezone, ActiveSupport::TimeZone] timezone of site or UTC fallback if site has no timezone.
        def site_timezone(site)
          return ActiveSupport::TimeZone['UTC'] if site.timezone.blank?

          TimeZoneHelper.tzinfo_class(site.tzinfo_tz)
        end
      end
    end
  end
end
