# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # Generate globally unique identifiers for resources, used in Camtrap Data Packages.
      # These identifiers are URLs pointing to the resource on the configured client host and port, with no protocol.
      module Identifier
        def self.site(site)
          with_host(Api::UrlHelpers.shallow_site_path(id: site.id))
        end

        def self.audio_recording(audio_recording)
          with_host(Api::UrlHelpers.audio_recording_path(id: audio_recording.id))
        end

        def self.tagging(tagging)
          audio_event = tagging.audio_event

          with_host(Api::UrlHelpers.audio_recording_audio_event_tagging_path(
            audio_recording_id: audio_event.audio_recording_id,
            audio_event_id: audio_event.id,
            id: tagging.id
          ))
        end

        # Generate a URL with the configured client host and port, for a given path.
        def self.with_host(path)
          port = Settings.client.port.present? ? ":#{Settings.client.port}" : ''

          "#{Settings.client.host}#{port}#{path}"
        end
      end
    end
  end
end
