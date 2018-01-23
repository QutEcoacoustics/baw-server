FactoryGirl.define do
  factory :progress_event do
    activity "viewed"

    dataset_item
    user
  end
end
