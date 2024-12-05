# frozen_string_literal: true

# == Schema Information
#
# Table name: harvest_items
#
#  id                 :bigint           not null, primary key
#  deleted            :boolean          default(FALSE)
#  info               :jsonb
#  path               :string
#  status             :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  audio_recording_id :integer
#  harvest_id         :integer
#  uploader_id        :integer          not null
#
# Indexes
#
#  index_harvest_items_on_harvest_id  (harvest_id)
#  index_harvest_items_on_info        (info) USING gin
#  index_harvest_items_on_path        (path)
#  index_harvest_items_on_status      (status)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  fk_rails_...  (harvest_id => harvests.id) ON DELETE => cascade
#  fk_rails_...  (uploader_id => users.id)
#
FactoryBot.define do
  factory :harvest_item do
    path { "#{harvest.upload_directory_name}/some/relative/path.mp3" }

    info { {} }
    status { :new }

    audio_recording
    uploader
    harvest
  end
end
