FactoryGirl.define do

  factory :site do
    sequence(:name) { |n| "site name #{n}" }
    #sequence(:notes) { |n|  {'a note': "note number #{n}"} }
    sequence(:description) { |n| "site description #{n}" }

    creator

    trait :with_lat_long do
      # Random.rand returns "a random integer greater than or equal to zero and less than the argument"
      # between -90 and 90 degrees
      latitude { Random.rand_incl(180.0) - 90.0 }
      # -180 and 180 degrees
      longitude { Random.rand_incl(360.0) - 180.0 }
    end

    # the after(:create) yields two values; the instance itself and the
    # evaluator, which stores all values from the factory, including transient
    # attributes; `create_list`'s second argument is the number of records
    # to create and we make sure the instance is associated properly to the list of items
    trait :with_audio_recordings do
      transient do
        audio_recording_count 1
      end
      after(:create) do |site, evaluator|
        raise 'Creator was blank' if  evaluator.creator.blank?
        create_list(:audio_recording_with_audio_events_and_bookmarks, evaluator.audio_recording_count,
                    site: site, creator: evaluator.creator, uploader: evaluator.creator)
      end
    end

    factory :site_with_lat_long, traits: [:with_lat_long]
    factory :site_with_audio_recordings, traits: [:with_lat_long, :with_audio_recordings]
  end
end