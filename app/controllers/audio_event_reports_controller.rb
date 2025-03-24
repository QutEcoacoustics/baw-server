# frozen_string_literal: true

class AudioEventReportsController < ApplicationController
  include Api::ControllerHelper

  # POST /audio_event_reports
  def filter
    # @audio_event_report = AudioEventReporter::AudioEventReport.new
    do_authorize_class(:filter, :audio_event_reports)
    report = AudioEventReporter::Report.new(api_filter_params, base_scope)
    query = report.generate
    result = ActiveRecord::Base.connection.execute(query).as_json
    render json: result, status: :ok
  end

  # audio events for which this user can access
  def base_scope
    Access::ByPermission.audio_events(current_user)
  end
end
