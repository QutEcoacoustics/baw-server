# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_imports
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  files       :jsonb
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  deleter_id  :integer
#  updater_id  :integer
#
FactoryBot.define do
  factory :audio_event_import do
    sequence(:name) { |n| "region name #{n}" }
    sequence(:description) { |n| "site **description** #{n}" }

    creator
    updater
  end
end
