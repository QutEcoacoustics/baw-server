FactoryGirl.define do

  factory :study do
    sequence(:name) { |n| "test study #{n}" }
    creator
    dataset

  end
end
