FactoryGirl.define do

  factory :tagging do
    creator
    audio_event

    after(:build) do |tagging, evaluator|
      if tagging.tag.blank?
        tagging.tag = FactoryGirl.create(:tag, creator: evaluator.creator)
      end
    end
  end

end

