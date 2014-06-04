FactoryGirl.define do

  factory :audio_recording do
    sequence(:file_hash) { |n| "SHA256::#{n}"  }
    recorded_date '2012-03-26 07:06:59'
    duration_seconds 60000
    sample_rate_hertz 22050
    channels 2
    bit_rate_bps 64000
    media_type 'audio/mp3'
    status 'ready'
    data_length_bytes 3800
    sequence(:notes) { |n| "note number #{n}" }
    sequence(:original_file_name) { |n| "original name #{n}" }

    association :creator
    association :uploader
    association :site

    trait :status_new do
      status 'new'
    end

    trait :status_ready do
      status 'ready'
    end

  end
end