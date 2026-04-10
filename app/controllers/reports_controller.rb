# frozen_string_literal: true

# Provides reporting endpoints for audio event analysis
class ReportsController < ApplicationController
  include Api::ControllerHelper
  include Api::Reporting
  include ResultFormatters

  # POST /reports/event_summaries
  # Returns a structured report of event summaries per tag and provenance groupings.
  # Accepts a filter object where:
  #  the `filter` is applied to audio events
  #  the `paging`, `sort` and `projection` options are invalid
  def event_summaries
    do_authorize_class(:filter, AudioEvent)

    base_query = Access::ByPermissionTable.audio_events(current_user, level: Access::Permission::READER)

    event_summaries_template = EventSummaries.new

    projections = {
      summary: event_summaries_template.event_summary
    }

    results, opts = execute_report(
      base_query:,
      template: event_summaries_template,
      projections:
    )

    score_keys = [:score_mean, :score_stddev, :score_minimum, :score_maximum, :score_histogram]

    results.map do |row|
      row => { summary:, **rest }

      histogram = extract_histogram(summary, histogram_key: :score_histogram)
      rest.merge(ensure_columns(score_keys, histogram))
    end => results

    respond_report(results, opts)
  end

  # POST /reports/tag_diel_activity
  # Returns a structured report of tag frequencies over diel time buckets.
  # Accepts a filter object where:
  #   the `filter` is applied to audio events
  #   the `paging`, `sort` and `projection` options are invalid
  # Accepts an `options` object where:
  #   `bucket_size` (required) interval for bucket aggregation
  def tag_diel_activity
    do_authorize_class(:filter, AudioEvent)

    base_query = Access::ByPermissionTable.audio_events(current_user, level: Access::Permission::READER)

    projections = {
      tags: TagDielActivity.tag_frequency_array
    }

    results, opts = execute_report(
      base_query:,
      template: TagDielActivity.new(report_options),
      projections:
    )

    respond_report(results, opts)
  end

  # POST /reports/tag_frequency
  # Returns a structured report of tag frequencies over time buckets.
  # Accepts a filter object where:
  #   the `filter` is applied to audio events
  #   the `paging`, `sort` and `projection` options are invalid
  # Accepts an `options` object where:
  #   `bucket_size` (required) interval for bucket aggregation
  def tag_frequency
    do_authorize_class(:filter, AudioEvent)

    base_query = Access::ByPermissionTable.audio_events(current_user, level: Access::Permission::READER)

    projections = {
      tags: TagFrequency.tag_frequency_array
    }

    results, opts = execute_report(
      base_query:,
      template: TagFrequency.new(report_options),
      projections:
    )

    respond_report(results, opts)
  end

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
