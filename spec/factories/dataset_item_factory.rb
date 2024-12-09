# frozen_string_literal: true

# == Schema Information
#
# Table name: dataset_items
#
#  id                 :integer          not null, primary key
#  end_time_seconds   :decimal(, )      not null
#  order              :decimal(, )
#  start_time_seconds :decimal(, )      not null
#  created_at         :datetime
#  audio_recording_id :integer
#  creator_id         :integer
#  dataset_id         :integer
#
# Indexes
#
#  dataset_items_idx  (start_time_seconds,end_time_seconds)
#
# Foreign Keys
#
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (dataset_id => datasets.id)
#
FactoryBot.define do
  factory :dataset_item do
    start_time_seconds { 11 }
    sequence(:end_time_seconds) { |n| n * 20.2 }
    sequence(:order) { |n| (n + 10.0) / 2 }

    audio_recording
    creator
    dataset
  end

  # this one doesn't try to create a new dataset if dataset is not passed
  # and instead just assigns the dataset id for the default dataset
  factory :default_dataset_item, class: 'DatasetItem' do
    start_time_seconds { 1441 }
    end_time_seconds { 1442 }
    sequence(:order) { |n| (n + 10.0) / 2 }

    # curly braces around the value to delay execution
    # https://stackoverflow.com/questions/12423273/factorygirl-screws-up-rake-dbmigrate-process
    dataset { Dataset.default_dataset }

    audio_recording
    creator
  end
end
