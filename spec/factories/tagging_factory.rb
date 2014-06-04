FactoryGirl.define do

  factory :tagging do
    association :creator
    tag
    audio_event
  end

end

