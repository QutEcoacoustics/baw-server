# frozen_string_literal: true

module AudioRecordings
  # Controller for creating downloader scripts
  class DownloaderController < ApplicationController
    include Api::ControllerHelper

    VIEW_NAME = 'audio_recordings/downloader/download_audio_files_ps1'
    SCRIPT_NAME = 'download_audio_files.ps1'

    # GET|POST /audio_recordings/downloader
    # Returns a script that can be used to download media segments or files.
    # Accepts an audio_recordings filter object via POST body to filter results.
    def index
      do_authorize_class(:index, :downloader)

      # we're not actually doing a query, discard it
      query, opts = Settings.api_response.response_advanced(
        api_filter_params,
        Access::ByPermission.audio_recordings(current_user),
        AudioRecording,
        AudioRecording.filter_settings
      )

      filter = build_filter_response_as_filter_query(query, opts)
      # ensure the needed fields (and only them) are returned
      filter[:projection] = { only: [:id, :recorded_date, :'sites.name', :site_id, :canonical_file_name] }

      @model = OpenStruct.new({
        app_version: Settings.version_string,
        user_name: current_user&.user_name || '',
        filter:,
        workbench_url: root_url.chop
      })

      script = render_to_string VIEW_NAME, layout: false
      send_data script, type: 'text/plain', filename: SCRIPT_NAME, disposition: 'attachment'
    end
  end
end
