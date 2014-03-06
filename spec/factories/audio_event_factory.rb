require 'faker'

FactoryGirl.define do

  factory :audio_event do

    start_time_seconds     Random.rand(86401)
    low_frequency_hertz    Random.rand(10000)

    owner
    creator
    audio_recording

    trait :high_frequency do
      high_frequency_hertz { low_frequency_hertz + Random.rand((10000 / 2) + 1) }
    end

    trait :end_time do
      end_time_seconds { start_time_seconds + Random.rand((86400 / 2) + 1) }
    end

    trait :reference do
      is_reference           true
    end

    trait :with_tags do
      ignore do
        audio_event_count 1
      end
      after(:create) do |audio_event, evaluator|
        create_list(:tagging, evaluator.audio_event_count, audio_event: audio_event)
      end
    end

    factory :audio_event_complete, traits: [:high_frequency, :end_time]
    factory :audio_event_complete_with_tags, traits: [:high_frequency, :end_time, :with_tags]
    factory :audio_event_with_tags, traits: [:with_tags]

  end

end