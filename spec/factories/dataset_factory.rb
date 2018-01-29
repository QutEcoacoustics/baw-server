FactoryGirl.define do
  factory :dataset do
    name "Dataset test name"
    description "This is a test dataset description."

    creator
    updater

  end
end
