# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_recordings
#
#  id                  :integer          not null, primary key
#  bit_rate_bps        :integer
#  channels            :integer
#  data_length_bytes   :bigint           not null
#  deleted_at          :datetime
#  duration_seconds    :decimal(10, 4)   not null
#  file_hash           :string(524)      not null
#  media_type          :string           not null
#  notes               :text
#  original_file_name  :string
#  recorded_date       :datetime         not null
#  recorded_utc_offset :string(20)
#  sample_rate_hertz   :integer
#  status              :string           default("new")
#  uuid                :string(36)       not null
#  created_at          :datetime
#  updated_at          :datetime
#  creator_id          :integer          not null
#  deleter_id          :integer
#  site_id             :integer          not null
#  updater_id          :integer
#  uploader_id         :integer          not null
#
# Indexes
#
#  audio_recordings_created_updated_at      (created_at,updated_at)
#  audio_recordings_icase_file_hash_id_idx  (lower((file_hash)::text), id)
#  audio_recordings_icase_file_hash_idx     (lower((file_hash)::text))
#  audio_recordings_icase_uuid_id_idx       (lower((uuid)::text), id)
#  audio_recordings_icase_uuid_idx          (lower((uuid)::text))
#  audio_recordings_uuid_uidx               (uuid) UNIQUE
#  index_audio_recordings_on_creator_id     (creator_id)
#  index_audio_recordings_on_deleter_id     (deleter_id)
#  index_audio_recordings_on_site_id        (site_id)
#  index_audio_recordings_on_updater_id     (updater_id)
#  index_audio_recordings_on_uploader_id    (uploader_id)
#
# Foreign Keys
#
#  audio_recordings_creator_id_fk   (creator_id => users.id)
#  audio_recordings_deleter_id_fk   (deleter_id => users.id)
#  audio_recordings_site_id_fk      (site_id => sites.id)
#  audio_recordings_updater_id_fk   (updater_id => users.id)
#  audio_recordings_uploader_id_fk  (uploader_id => users.id)
#
require "#{__dir__}/../helpers/misc_helper"

FactoryBot.define do
  factory :audio_recording do
    sequence(:file_hash) { |n| MiscHelper.new.create_sha_256_hash(n) }
    sequence(:recorded_date) { |n| (DateTime.parse('2012-03-26 07:06:59') + n.to_i.day).to_s }
    duration_seconds { 60_000 }
    sample_rate_hertz { 22_050 }
    channels { 2 }
    bit_rate_bps { 64_000 }
    media_type { 'audio/mpeg' }
    data_length_bytes { 3800 }
    sequence(:notes) { |n| { test: "note number #{n}" } }
    sequence(:original_file_name) { |n| "original name #{n}.mp3" }

    creator
    uploader do
      # admin user
      User.find(1)
    end
    site

    trait :status_new do
      status { 'new' }
    end

    trait :status_ready do
      status { 'ready' }
    end

    trait :with_audio_events do
      transient do
        audio_event_count  { 1 }
      end
      after(:create) do |audio_recording, evaluator|
        raise 'Creator was blank' if evaluator.creator.blank?

        create_list(:audio_event_with_tags_and_comments, evaluator.audio_event_count, audio_recording: audio_recording,
creator: evaluator.creator)
      end
    end

    trait :with_bookmarks do
      transient do
        bookmark_count { 1 }
      end
      after(:create) do |audio_recording, evaluator|
        raise 'Creator was blank' if evaluator.creator.blank?

        create_list(:bookmark, evaluator.bookmark_count, audio_recording: audio_recording, creator: evaluator.creator)
      end
    end

    factory :audio_recording_with_audio_events_and_bookmarks,
      traits: [:with_audio_events, :with_bookmarks, :status_ready]
  end
end
