# frozen_string_literal: true

# == Schema Information
#
# Table name: bookmarks
#
#  id                 :integer          not null, primary key
#  category           :string
#  description        :text
#  name               :string
#  offset_seconds     :decimal(10, 4)
#  created_at         :datetime
#  updated_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer          not null
#  updater_id         :integer
#
# Indexes
#
#  bookmarks_name_creator_id_uidx         (name,creator_id) UNIQUE
#  index_bookmarks_on_audio_recording_id  (audio_recording_id)
#  index_bookmarks_on_creator_id          (creator_id)
#  index_bookmarks_on_updater_id          (updater_id)
#
# Foreign Keys
#
#  bookmarks_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  bookmarks_creator_id_fk          (creator_id => users.id)
#  bookmarks_updater_id_fk          (updater_id => users.id)
#
FactoryBot.define do
  factory :bookmark do
    offset_seconds { 4 }
    sequence(:description) { |n| "description #{n}" }
    sequence(:name) { |n| "name #{n}" }
    sequence(:category) { |n| "category #{n}" }

    creator
    audio_recording
  end
end
