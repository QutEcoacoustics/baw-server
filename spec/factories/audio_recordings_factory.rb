FactoryGirl.define do

  factory :audio_recording do
    sequence(:file_hash) { |n| "SHA256::#{n}"  }
    recorded_date '2012-03-26 07:06:59'
    duration_seconds 60000
    sample_rate_hertz 22050
    channels 2
    bit_rate_bps 64000
    media_type 'audio/mp3'
    data_length_bytes 3800
    sequence(:notes) { |n| "note number #{n}" }
    sequence(:original_file_name) { |n| "original name #{n}.mp3" }

    creator
    uploader
    site

    trait :status_new do
      status 'new'
    end

    trait :status_ready do
      status 'ready'
    end

    trait :with_audio_events do
      ignore do
        audio_event_count 1
      end
      after(:create) do |audio_recording, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:audio_event_with_tags, evaluator.audio_event_count, audio_recording: audio_recording, creator: evaluator.creator)
      end
    end

    factory :audio_recording_with_audio_events, traits: [:with_audio_events, :status_ready]

  end
end