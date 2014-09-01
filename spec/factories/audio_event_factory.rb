FactoryGirl.define do

  factory :audio_event do

    start_time_seconds 5.2
    low_frequency_hertz 400
    high_frequency_hertz 6000
    end_time_seconds 5.8

    creator
    audio_recording

    trait :reference do
      is_reference true
    end

    trait :with_tags do
      ignore do
        audio_event_count 1
      end
      after(:create) do |audio_event, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:tagging, evaluator.audio_event_count, audio_event: audio_event, creator: evaluator.creator)
      end
    end

    trait :with_comments do
      ignore do
        audio_event_count 1
      end
      after(:create) do |audio_event, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:comment, evaluator.audio_event_count, audio_event: audio_event, creator: evaluator.creator)
      end
    end

    factory :audio_event_with_tags, traits: [:with_tags]
    factory :audio_event_with_comments, traits: [:with_comments]
    factory :audio_event_with_tags_and_comments, traits: [:with_tags, :with_comments]
    factory :audio_event_reference_with_tags, traits: [:with_tags, :reference]
  end
end