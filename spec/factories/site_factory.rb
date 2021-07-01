# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                 :integer          not null, primary key
#  deleted_at         :datetime
#  description        :text
#  image_content_type :string
#  image_file_name    :string
#  image_file_size    :integer
#  image_updated_at   :datetime
#  latitude           :decimal(9, 6)
#  longitude          :decimal(9, 6)
#  name               :string           not null
#  notes              :text
#  rails_tz           :string(255)
#  tzinfo_tz          :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  creator_id         :integer          not null
#  deleter_id         :integer
#  region_id          :integer
#  updater_id         :integer
#
# Indexes
#
#  index_sites_on_creator_id  (creator_id)
#  index_sites_on_deleter_id  (deleter_id)
#  index_sites_on_updater_id  (updater_id)
#
# Foreign Keys
#
#  fk_rails_...         (region_id => regions.id)
#  sites_creator_id_fk  (creator_id => users.id)
#  sites_deleter_id_fk  (deleter_id => users.id)
#  sites_updater_id_fk  (updater_id => users.id)
#
FactoryBot.define do
  factory :site do
    sequence(:name) { |n| "site name #{n}" }
    sequence(:notes) { |n| "note number #{n}" }
    sequence(:description) { |n| "site description #{n}" }

    creator

    trait :with_lat_long do
      # Random.rand returns "a random integer greater than or equal to zero and less than the argument"
      # between -90 and 90 degrees
      latitude { Random.rand(-90.0..90.0) }
      # -180 and 180 degrees
      longitude { Random.rand(-180.0..180.0) }
    end

    # the after(:create) yields two values; the instance itself and the
    # evaluator, which stores all values from the factory, including transient
    # attributes; `create_list`'s second argument is the number of records
    # to create and we make sure the instance is associated properly to the list of items
    trait :with_audio_recordings do
      transient do
        audio_recording_count { 1 }
      end
      after(:create) do |site, evaluator|
        raise 'Creator was blank' if evaluator.creator.blank?

        create_list(:audio_recording_with_audio_events_and_bookmarks, evaluator.audio_recording_count,
                    site: site, creator: evaluator.creator, uploader: evaluator.creator)
      end
    end

    factory :site_with_lat_long, traits: [:with_lat_long]
    factory :site_with_audio_recordings, traits: [:with_lat_long, :with_audio_recordings]
  end
end
