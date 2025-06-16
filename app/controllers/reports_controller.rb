# frozen_string_literal: true

class ReportsController < ApplicationController
  include Api::ControllerHelper

  # POST /reports/audio_event_summary
  def summary
    do_authorize_class(:summary, :reports)

    # NOTE: api_filter_params is permit! all validation done in modules
    report = Report::AudioEventReport.new(api_filter_params, base_scope)
    result = report.generate
    render json: result, status: :ok
  end

  # audio events for which this user can access
  def base_scope
    Access::ByPermission.audio_events(current_user)
  end
end
