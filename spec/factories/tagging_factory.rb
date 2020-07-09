# frozen_string_literal: true

FactoryBot.define do
  factory :tagging do
    creator
    audio_event
    tag
  end
end
