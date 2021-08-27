# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recording_statistics
#
#  bucket                    :tsrange          not null, primary key
#  original_download_count   :bigint           default(0)
#  segment_download_count    :bigint           default(0)
#  segment_download_duration :decimal(, )      default(0.0)
#  audio_recording_id        :bigint           not null, primary key
#
# Indexes
#
#  constraint_baw_audio_recording_statistics_non_overlapping  (audio_recording_id,bucket) USING gist
#  constraint_baw_audio_recording_statistics_unique           (audio_recording_id,bucket) UNIQUE
#  index_audio_recording_statistics_on_audio_recording_id     (audio_recording_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#
FactoryBot.define do
  factory :audio_recording_statistics do
    original_download_count { 0 }
    segment_download_count { 0 }
    segment_download_duration { 0 }

    audio_recording
  end
end
