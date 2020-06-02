FactoryGirl.define do
  factory :response do
    data_json = <<~JSON
        {"labels_present": [1,2]}
    JSON
    data data_json
    creator
    study
    dataset_item
  end
end
