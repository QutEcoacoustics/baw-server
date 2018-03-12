FactoryGirl.define do
  factory :dataset_item do

    start_time_seconds 11
    sequence(:end_time_seconds) { |n| n*20.2 }
    sequence(:order) { |n| (n+10.0)/2 }

    dataset
    audio_recording
    creator

  end
end
