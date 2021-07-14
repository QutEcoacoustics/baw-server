# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_status  (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#  fk_rails_...  (uploader_id => users.id)
#
class HarvestItem < ApplicationRecord
  # optional audio recording - when a harvested audio file is complete, it will match a recording
  has_one :audio_recording, required: false # dependent: :nil,

  validates :path, presence: true, length: { minimum: 2 }
end
