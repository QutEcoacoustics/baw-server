FactoryGirl.define do
  factory :bookmark do
    offset_seconds 4
    sequence(:description) { |n| "description #{n}" }
    sequence(:name) { |n| "name #{n}" }

    association :creator
    association :audio_recording

  end
end

