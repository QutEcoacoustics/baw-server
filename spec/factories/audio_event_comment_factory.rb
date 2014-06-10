FactoryGirl.define do

  factory :audio_event_comment do

    comment "Hey look, I have comments! Can't stop me now."

    association :creator
    association :audio_event

    trait :reported do
      flag 'report'
      association :flagger
    end

    factory :audio_event_comment_reported, traits: [:reported]
  end
end