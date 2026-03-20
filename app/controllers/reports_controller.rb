# frozen_string_literal: true

class ReportsController < ApplicationController
  include Api::ControllerHelper
  include Api::Reporting

  # POST /reports/tag_accumulation
  # Returns a structured report of cumulative unique tag counts over time buckets.
  # Accepts a filter object where:
  #   the `filter` is applied to audio events
  #   the `paging`, `sort` and `projection` options are invalid
  # Accepts an `options` object where:
  #   `bucket_size` (required) interval for bucket aggregation
  def tag_accumulation
    do_authorize_class(:filter, AudioEvent)

    base_query = Access::ByPermissionTable.audio_events(current_user, level: Access::Permission::READER)

    projections = {
      bucket: Bucketer::BUCKETS[:bucket],
      cumulative_unique_tag_count: TagAccumulation.cumulative_count
    }

    results, opts = execute_report(
      base_query:,
      template: TagAccumulation.new(report_options),
      projections:
    )

    respond_report(results, opts)
  end

  private

  # @return [Hash]
  def report_options
    options = api_options_params
    options.require(:bucket_size)
    options.permit(:bucket_size).to_h
  end
end
