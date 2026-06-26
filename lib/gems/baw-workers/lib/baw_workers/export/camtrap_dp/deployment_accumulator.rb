# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Accumulate deployment information from taggings.
      #
      # We use Site as a proxy for a deployment, and calculate deployment start and end time based on the audio
      # recordings at the site in the result set.
      class DeploymentAccumulator
        Deployment = Data.define(:site, :start, :end, :file_public)

        def initialize
          @deployments = {}
        end

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
            file_public: audio_recording.site.public_site?
          )

          @deployments[audio_recording.site_id] = Deployment.new(
            site: deployment.site,
            start: earliest(deployment.start, audio_recording.recorded_date),
            end: latest(deployment.end, audio_recording.recorded_end_date),
            file_public: deployment.file_public
          )
        end

        def earliest(*times) = times.compact.min
        def latest(*times) = times.compact.max

        def values = @deployments.values
      end
    end
  end
end
