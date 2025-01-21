# frozen_string_literal: true

# == Schema Information
#
# Table name: verifications
#
#  id             :bigint           not null, primary key
#  confirmed      :enum             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  audio_event_id :bigint           not null
#  creator_id     :integer          not null
#  tag_id         :bigint           not null
#  updater_id     :integer
#
# Indexes
#
#  idx_on_audio_event_id_tag_id_creator_id_f944f25f20  (audio_event_id,tag_id,creator_id) UNIQUE
#  index_verifications_on_audio_event_id               (audio_event_id)
#  index_verifications_on_tag_id                       (tag_id)
#
# Foreign Keys
#
#  fk_rails_...  (audio_event_id => audio_events.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (tag_id => tags.id) ON DELETE => cascade
#  fk_rails_...  (updater_id => users.id)
#
FactoryBot.define do
  factory :verification do
    creator
    audio_event
    tag
    confirmed { Verification::CONFIRMATION_TRUE }
  end
end
