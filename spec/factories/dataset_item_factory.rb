FactoryGirl.define do

  factory :dataset_item do

    start_time_seconds 11
    sequence(:end_time_seconds) { |n| n*20.2 }
    sequence(:order) { |n| (n+10.0)/2 }

    audio_recording
    creator
    dataset

  end

  # this one doesn't try to create a new dataset if dataset is not passed
  # and instead just assigns the dataset id for the default dataset
  factory :default_dataset_item, class: 'DatasetItem' do

    start_time_seconds 1441
    end_time_seconds 1442
    sequence(:order) { |n| (n+10.0)/2 }

    # curly braces around the value to delay execution
    # https://stackoverflow.com/questions/12423273/factorygirl-screws-up-rake-dbmigrate-process
    dataset_id { Dataset.default_dataset_id }

    audio_recording
    creator

  end

end
