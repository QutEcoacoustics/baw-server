# frozen_string_literal: true

FactoryBot.define do
  factory :verification do |_f|
    audio_event
    tag
    creator
    confirmed { Verification::CONFIRMATION_TRUE }
  end
end
