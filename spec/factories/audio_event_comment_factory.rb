# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_comments
#
#  id             :integer          not null, primary key
#  comment        :text             not null
#  deleted_at     :datetime
#  flag           :string
#  flag_explain   :text
#  flagged_at     :datetime
#  created_at     :datetime
#  updated_at     :datetime
#  audio_event_id :integer          not null
#  creator_id     :integer          not null
#  deleter_id     :integer
#  flagger_id     :integer
#  updater_id     :integer
#
# Indexes
#
#  index_audio_event_comments_on_audio_event_id  (audio_event_id)
#  index_audio_event_comments_on_creator_id      (creator_id)
#  index_audio_event_comments_on_deleter_id      (deleter_id)
#  index_audio_event_comments_on_flagger_id      (flagger_id)
#  index_audio_event_comments_on_updater_id      (updater_id)
#
# Foreign Keys
#
#  audio_event_comments_audio_event_id_fk  (audio_event_id => audio_events.id) ON DELETE => cascade
#  audio_event_comments_creator_id_fk      (creator_id => users.id)
#  audio_event_comments_deleter_id_fk      (deleter_id => users.id)
#  audio_event_comments_flagger_id_fk      (flagger_id => users.id)
#  audio_event_comments_updater_id_fk      (updater_id => users.id)
#
FactoryBot.define do
  factory :audio_event_comment, aliases: [:comment] do
    sequence(:comment) { |n| "comment text #{n}" }

    creator
    audio_event

    trait :reported do
      flag { 'report' }
      association :flagger
    end

    factory :audio_event_comment_reported, traits: [:reported]
  end
end
