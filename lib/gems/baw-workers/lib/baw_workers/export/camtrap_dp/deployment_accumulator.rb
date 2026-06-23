# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Accumulates deployment information from taggings.
      #
      # We don't have a deployment model, so we use Site as a deployment and infer the deployment start and end from the
      # audio recordings at the site. Deployment start and end is updated while processing taggings for efficiency.
      class DeploymentAccumulator
        Deployment = Data.define(:site, :start, :end, :file_public)

        def initialize
          @deployments = {}
        end

        # @param tagging [Tagging] the tagging for the deployment
        # @return [Deployment] the new or updated deployment for the tagging's site
        def upsert_deployment(tagging)
          audio_recording = tagging.audio_event.audio_recording
          site = audio_recording.site
          deployment = @deployments[audio_recording.site_id] || Deployment.new(
            site:,
            start: nil,
            end: nil,
            file_public: site.public_site?
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
