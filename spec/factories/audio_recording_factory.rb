FactoryGirl.define do

  factory :audio_recording do
    sequence(:file_hash) { |n| MiscHelper.new.create_sha_256_hash(n)}
    recorded_date '2012-03-26 07:06:59'
    duration_seconds 60000
    sample_rate_hertz 22050
    channels 2
    bit_rate_bps 64000
    media_type 'audio/mpeg'
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
      transient do
        audio_event_count 1
      end
      after(:create) do |audio_recording, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:audio_event_with_tags_and_comments, evaluator.audio_event_count, audio_recording: audio_recording, creator: evaluator.creator)
      end
    end

    trait :with_bookmarks do
      transient do
        bookmark_count 1
      end
      after(:create) do |audio_recording, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:bookmark, evaluator.bookmark_count, audio_recording: audio_recording, creator: evaluator.creator)
      end
    end

    factory :audio_recording_with_audio_events_and_bookmarks, traits: [:with_audio_events, :with_bookmarks, :status_ready]

  end
end