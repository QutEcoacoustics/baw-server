# frozen_string_literal: true

FactoryBot.define do
  factory :bookmark do
    offset_seconds { 4 }
    sequence(:description) { |n| "description #{n}" }
    sequence(:name) { |n| "name #{n}" }
    sequence(:category) { |n| "category #{n}" }

    creator
    audio_recording
  end
end
