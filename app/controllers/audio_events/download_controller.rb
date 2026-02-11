# frozen_string_literal: true

module AudioEvents
  # Controller for downloading audio event annotations as CSV.
  # Separated from AudioEventsController to isolate streaming concerns.
  class DownloadController < ApplicationController
    include Api::ControllerHelper
    include Api::RawPostgresStreamer

    skip_authorization_check only: []

    # GET /audio_recordings/:audio_recording_id/audio_events/download
    # GET /projects/:project_id/audio_events/download
    # GET /projects/:project_id/regions/:region_id/audio_events/download
    # GET /projects/:project_id/sites/:site_id/audio_events/download
    # GET /user_accounts/:user_id/audio_events/download
    def download
      params_cleaned = CleanParams.perform(download_params)

      is_authorized = false

      user = nil
      project = nil
      site = nil
      audio_recording = nil
      end_offset = nil

      # check which params are available to authorize this request

      # user id
      if params_cleaned[:user_id]
        user = User.where(id: params_cleaned[:user_id].to_i).first
        if user.present?
          authorize! :audio_events, user
          is_authorized = true
        end
      end

      # project id
      if params_cleaned[:project_id]
        project = Project.where(id: params_cleaned[:project_id].to_i).first
        if project.present?
          authorize! :show, project
          is_authorized = true
        end
      end

      # region id
      if params_cleaned[:region_id]
        region = Region.where(id: params_cleaned[:region_id].to_i).first
        if region.present?
          authorize! :show, region
          is_authorized = true
        end
      end

      # site id
      if params_cleaned[:site_id]
        site = Site.where(id: params_cleaned[:site_id].to_i).first
        if site.present?
          authorize! :show, site
          is_authorized = true
        end
      end

      if params_cleaned[:audio_event_import_id]
        import = AudioEventImport.where(id: params_cleaned[:audio_event_import_id].to_i).first
        if import.present?
          authorize! :show, import
          # We check authorization on the import, but we don't want this to be
          # the only factor we auth since imports can be accessible even if you
          # don't have access to the underlying audio events.
          #is_authorized = true
        end
      end

      # audio recording id
      audio_recording_id = params_cleaned[:audio_recording_id] || params_cleaned[:recording_id] || params_cleaned[:audiorecording_id] || nil
      if audio_recording_id
        audio_recording = AudioRecording.where(id: audio_recording_id.to_i).first
        if audio_recording.present?
          authorize! :show, audio_recording
          is_authorized = true
        end
      end

      # start offset
      start_offset = if params_cleaned[:start_offset]
                       params_cleaned[:start_offset].to_f
                     else
                       0
                     end

      # end offset
      if params_cleaned[:end_offset]
        end_offset = params_cleaned[:end_offset].to_f
      elsif audio_recording
        end_offset = audio_recording.duration_seconds
      end

      # timezone
      timezone_name = params_cleaned[:selected_timezone_name] || 'UTC'

      unless is_authorized
        raise CustomErrors::RoutingArgumentError,
          'must provide existing (audio_recording_id, start_offset, and end_offset) or project_id, region_id, site_id, or user_id'
      end

      # create file name
      time_now = Time.zone.now
      file_name_append = time_now.strftime('%Y%m%d-%H%M%S').to_s
      file_name = 'annotations'

      file_name = NameyWamey.create_user_name(user) if user.present?

      file_name = NameyWamey.create_project_name(project) if project.present?

      file_name = NameyWamey.create_site_name(site.projects.first, site) if site.present?

      if audio_recording.present?
        file_name = NameyWamey.create_audio_recording_name(audio_recording, start_offset, end_offset)
      end

      # create query
      query = AudioEvent.csv_query(
        user, project, region, site, audio_recording, start_offset, end_offset, timezone_name, import
      )
      query_sql = query.to_sql

      respond_to do |format|
        format.csv do
          stream_query_as_csv(query_sql, "#{file_name.trim('.', '')}-#{file_name_append}",
            connection: AudioEvent.connection)
        end
        format.json do
          stream_query_as_columnar_json(query_sql, "#{file_name.trim('.', '')}-#{file_name_append}",
            connection: AudioEvent.connection)
        end
      end
    end

    private

    def download_params
      params.permit(
        :audio_recording_id, :audioRecordingId, :audiorecording_id, :audiorecordingId, :recording_id, :recordingId,
        :user_id, :userId,
        :project_id, :projectId,
        :site_id, :siteId,
        :region_id, :regionId,
        :start_offset, :startOffset,
        :end_offset, :endOffset,
        :selected_timezone_name, :selectedTimezoneName,
        :audio_event_import_id, :audioEventImportId,
        :format
      )
    end
  end
end
