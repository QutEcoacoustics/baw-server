FactoryGirl.define do

  factory :audio_event do

    start_time_seconds 5.2
    low_frequency_hertz 400
    high_frequency_hertz 6000
    end_time_seconds 5.8

    association :creator
    association :audio_recording

    trait :is_a_reference do
      is_reference true
    end

    factory :audio_event_reference, traits: [:is_a_reference]

  end
end