require 'faker'

FactoryGirl.define do

  factory :audio_recording do
    sequence(:file_hash) { |n| "SHA256::#{n}"  }
    recorded_date '2012-03-26 07:06:59'
    duration_seconds Random.rand(86401.0)
    sample_rate_hertz (Random.rand(441) + 1) * 100
    channels Random.rand(2) + 1
    bit_rate_bps (Random.rand(64) + 1) * 100
    media_type ['audio/mp3', 'audio/wav', 'audio/webm', 'audio/ogg'].sample
    data_length_bytes Random.rand(5000)

    creator
    uploader
    site

    trait :notes do
      notes { {Faker::Lorem.word => Faker::Lorem.word} }
    end

    trait :status_new do
      status 'new'
    end

    trait :status_ready do
      status 'ready'
    end

    trait :status_random do
      status AudioRecording::AVAILABLE_STATUSES.sample
    end

    trait :original_file_name do
      original_file_name { "#{Faker::Lorem.word}.#{media_type.gsub('audio/', '')}" }
    end

    trait :with_audio_events do
      ignore do
        audio_event_count 1
      end
      after(:create) do |audio_recording, evaluator|
        create_list(:audio_event_with_tags, evaluator.audio_event_count, audio_recording: audio_recording)
      end
    end

    factory :audio_recording_with_audio_events, traits: [:with_audio_events, :status_ready]

  end
end