# frozen_string_literal: true

class AudioEventReportsController < ApplicationController
  include Api::ControllerHelper

  # POST /audio_event_reports
  def filter
    # @audio_event_report = AudioEventReporter::AudioEventReport.new
    do_authorize_class(:filter, :audio_event_reports)

    # NOTE: api_filter_params is permit! all validation done in modules
    report = Report::AudioEventReport.new(api_filter_params, base_scope)
    result = report.generate
    respond_report(result)
  end

  # audio events for which this user can access
  def base_scope
    Access::ByPermission.audio_events(current_user)
  end

  def respond_report(content, opts = {})
    content_type = 'application/json'
    built_response = Settings.api_response.build(:ok, content)

    if request.head?
      head :ok, { content_length: built_response.to_json.bytesize, content_type: }
    else
      render json: built_response, status: :ok, content_type:, layout: false
    end
  end
end
