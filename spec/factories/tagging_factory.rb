# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events_tags
#
#  id             :integer          not null, primary key
#  created_at     :datetime
#  updated_at     :datetime
#  audio_event_id :integer          not null
#  creator_id     :integer          not null
#  tag_id         :integer          not null
#  updater_id     :integer
#
# Indexes
#
#  index_audio_events_tags_on_audio_event_id_and_tag_id  (audio_event_id,tag_id) UNIQUE
#  index_audio_events_tags_on_creator_id                 (creator_id)
#  index_audio_events_tags_on_updater_id                 (updater_id)
#
# Foreign Keys
#
#  audio_events_tags_audio_event_id_fk  (audio_event_id => audio_events.id) ON DELETE => cascade
#  audio_events_tags_creator_id_fk      (creator_id => users.id)
#  audio_events_tags_tag_id_fk          (tag_id => tags.id)
#  audio_events_tags_updater_id_fk      (updater_id => users.id)
#
FactoryBot.define do
  factory :tagging do
    creator
    audio_event
    tag
  end
end
