require 'faker'

FactoryGirl.define do
  factory :required_audio_event_attributes, class: AudioEvent do
    # factory generally used to create attributes for POST requests
    # to create an audio_event with all dependencies, check permission_factory.rb
    start_time_seconds     Random.rand(100) + 10 + 0.123456  # making sure start is over 10 so it doesn't interfere with tests against specific times
    low_frequency_hertz    Random.rand(100) + 0.123456
    factory :all_audio_event_attributes, class: AudioEvent do
      end_time_seconds       Random.rand(100) + 200 + 0.123456
      high_frequency_hertz   Random.rand(100) + 4000 + 0.123456
      is_reference           false
      factory :audio_event do
        association :creator, factory: :user
        association :audio_recording
      end
    end
  end
end