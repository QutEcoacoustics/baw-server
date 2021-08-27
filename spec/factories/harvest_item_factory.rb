# frozen_string_literal: true

FactoryBot.define do
  factory :harvest_item do
    path { 'some/relative/path.mp3' }
    info { {} }
    status { :new }

    audio_recording
    uploader
  end
end
