# frozen_string_literal: true

# Controller for the stats endpoint
class StatsController < ApplicationController
  skip_authorization_check only: [:index]

  # GET /stats
  # only returns json
  def index
    result = StatsController.fetch_stats(current_user)

    # Simplify the response, by mutation. Show only ids from active record models.
    result[:recent]
      .transform_keys! { |key| :"#{key.to_s[..-2]}_ids" }
      .transform_values! { |query| query.pluck(:id) }

    built_response = Settings.api_response.build(:ok, result)
    render json: built_response, status: :ok, layout: false
  end

  def self.fetch_stats(current_user)
    online_window = 2.hours.ago
    recent_window = 1.month.ago
    recent_limit = 10
    {
      summary: {
        users_online: User.recently_seen(online_window).count,
        users_total: User.count,
        online_window_start: online_window,
        projects_total: Project.count,
        regions_total: Region.count,
        sites_total: Site.count,
        annotations_total: AudioEvent.count,
        annotations_total_duration: AudioEvent.total_duration_seconds,
        annotations_recent: AudioEvent.recent_within(recent_window).count,
        audio_recordings_total: AudioRecording.count,
        audio_recordings_recent: AudioRecording.created_within(recent_window).count,
        audio_recordings_total_duration: AudioRecording.total_duration_seconds,
        audio_recordings_total_size: AudioRecording.total_data_bytes.to_i,
        tags_total: Tag.count,
        tags_applied_total: Tagging.count,
        tags_applied_unique_total: Tagging.count_unique
      },
      recent: {
        audio_recordings: Access::ByPermission.audio_recordings(current_user).most_recent(recent_limit),
        audio_events: Access::ByPermission.audio_events(current_user).most_recent(recent_limit)
      }
    }
  end
end
