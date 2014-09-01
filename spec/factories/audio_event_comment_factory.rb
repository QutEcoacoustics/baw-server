FactoryGirl.define do

  factory :audio_event_comment do

    sequence(:comment) { |n| "comment text #{n}" }

    creator
    audio_event

    trait :reported do
      flag 'report'
      association :flagger
    end

    factory :audio_event_comment_reported, traits: [:reported]
  end
end
