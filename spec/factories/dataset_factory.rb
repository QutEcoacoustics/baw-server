FactoryGirl.define do

  factory :dataset do
    sequence(:name) { |n| "gen_dataset_name#{n}" }
    sequence(:description) { |n| "dataset description #{n}" }

    creator
    updater

  end
end
