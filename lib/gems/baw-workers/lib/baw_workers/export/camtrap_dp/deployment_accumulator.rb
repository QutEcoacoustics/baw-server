# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Accumulate deployment related metadata for taggings.
      #
      # We use Site as a proxy for a deployment, and calculate deployment start and end time based on the audio
      # recordings at the site in the result set.
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
          # @return [Time, ActiveSupport::TimeWithZone, nil] timestamp converted to the deployment's timezone, ready for Camtrap-DP ISO 8601 serialization.
          def ensure_timezone(time)
            return nil if time.blank?

            # return time.utc if timezone.nil?

            time.in_time_zone(timezone)
          end
        }

        # Add a deployment for the tagging's site if it doesn't exist, or update the existing deployment's start and end
        # times if it does. Initialize the deployment's timezone based on the site's timezone, unless a forced_timezone
        # was provided to the accumulator.
        #
        # This isn't a problem now, but it's worth noting: deployments are keyed by site_id, and site is cached the
        # first time seen. So when using find_each in batches, the same site from a later batch will have a different
        # object_id than the cached site object.
        #
        # @param tagging [Tagging] the tagging for the deployment
        # @return [Deployment] the new or updated deployment for the tagging's site
        def add_or_update(tagging)
          audio_recording = tagging.audio_event.audio_recording
          deployment = @deployments[audio_recording.site_id] || Deployment.new(
            site: audio_recording.site, # this will be the object from the first time it was seen in a batch
            start: nil,
            end: nil,
            file_public: audio_recording.site.public_site?,
            timezone: @forced_timezone || site_timezone(audio_recording.site)
          )

          @deployments[audio_recording.site_id] = deployment.with(
            start: deployment.ensure_timezone(earliest(deployment.start, audio_recording.recorded_date)),
            end: deployment.ensure_timezone(latest(deployment.end, audio_recording.recorded_end_date))
          )
        end

        def earliest(*times) = times.compact.min
        def latest(*times) = times.compact.max

        def values = @deployments.values

        private

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
