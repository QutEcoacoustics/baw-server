require 'faker'

FactoryGirl.define do

  factory :required_audio_recording_attributes do
    # factory generally used to create attributes for POST requests
    # to create an audio_recording with all dependencies, check permission_factory.rb
    recorded_date       '2012-03-26 07:06:59'
    duration_seconds    Random.rand(600)
    media_type          ['audio/mp3', 'audio/wav', 'audio/webm'].sample
    data_length_bytes   Random.rand(64)
    file_hash           'SHA256::fbb815630fa3b432003f3c11aea4b8da566c20d05601f2adedfb9407991f87ac'
    original_file_name   'test.wav'
    association :creator, factory: :harvester
    association :site, factory: :site
    association :uploader, factory: :user

    factory :all_audio_recording_attributes, class: AudioRecording do
      sample_rate_hertz   Random.rand(441) * 100
      channels            Random.rand(2) + 1
      bit_rate_bps        Random.rand(64) * 100
      status              'ready'
      notes { {Faker::Lorem.word => Faker::Lorem.paragraph} }

      factory :audio_recording do

      end
    end
  end
end