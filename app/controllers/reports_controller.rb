# frozen_string_literal: true

class ReportsController < ApplicationController
  include Api::ControllerHelper

  # POST /reports/audio_event_summary
  def summary
    do_authorize_class(:summary, :reports)

    # NOTE: api_filter_params is permit! all validation done in modules
    parameters = filter_params_to_hash(api_filter_params)

    scope = filter_as_relation(base_scope, parameters)

    result = call_report(scope, parameters)
    formatted_result = format_report(result)

    debugger
    render json: formatted_result, status: :ok
  end

  # Normalise filter parameters, extracted from Api::Response#response
  # @param params [Hash]
  # @return [HashWithIndifferentAccess]
  def filter_params_to_hash(params)
    params = params.to_h if params.is_a? ActionController::Parameters
    return params if params.is_a? ActiveSupport::HashWithIndifferentAccess

    raise ArgumentError,
      'params needs to be HashWithIndifferentAccess' \
      'or an ActionController::Parameters'
  end

  # @param filter_params [ActionController::Parameters] the filter parameters
  # @param base_scope [ActiveRecord::Relation] base permissions scope to use
  def filter_as_relation(base_scope, filter_params)
    filter_query = Filter::Query.new(
      filter_params,
      base_scope,
      AudioEvent,
      AudioEvent.filter_settings
    )
    filter_query.query_without_paging_sorting
  end

  # audio events for which this user can access
  def base_scope
    Access::ByPermission.audio_events(current_user)
  end

  def call_report(scope, parameters)
    options = parameters
      .fetch(:options, {})
      .deep_symbolize_keys
      .merge({ base_scope: scope.arel })

    Report::AudioEvents.new(options: options).execute
  end

  def format_report(result)
    Report::AudioEvents.format_result(result)
  end
end
