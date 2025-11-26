# frozen_string_literal: true

# == Schema Information
#
# Table name: sites
#
#  id                   :integer          not null, primary key
#  deleted_at           :datetime
#  description          :text
#  image_content_type   :string
#  image_file_name      :string
#  image_file_size      :bigint
#  image_updated_at     :datetime
#  latitude             :decimal(9, 6)
#  longitude            :decimal(9, 6)
#  name                 :string           not null
#  notes                :text
#  obfuscated_latitude  :decimal(9, 6)
#  obfuscated_longitude :decimal(9, 6)
#  rails_tz             :string(255)
#  tzinfo_tz            :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  creator_id           :integer          not null
#  deleter_id           :integer
#  region_id            :integer
#  updater_id           :integer
#
# Indexes
#
#  index_sites_on_creator_id            (creator_id)
#  index_sites_on_deleter_id            (deleter_id)
#  index_sites_on_obfuscated_latitude   (obfuscated_latitude)
#  index_sites_on_obfuscated_longitude  (obfuscated_longitude)
#  index_sites_on_updater_id            (updater_id)
#
# Foreign Keys
#
#  fk_rails_...         (region_id => regions.id) ON DELETE => cascade
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
    # AT 2025: possibly breaking change. These two associations used to create
    # two independent projects. Now they only do one.
    transient do
      shared_project { create(:project) }
    end
    region { create(:region, project: shared_project) }
    projects { region.present? ? [region.project] : [shared_project] }

    trait :with_lat_long do
      # Random.rand returns "a random integer greater than or equal to zero and less than the argument"
      # between -90 and 90 degrees
      latitude { Random.rand(-90.0..90.0) }
      # -180 and 180 degrees
      longitude { Random.rand(-180.0..180.0) }

      custom_obfuscated_location { false }
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
          site:, creator: evaluator.creator, uploader: evaluator.creator)
      end
    end

    factory :site_with_lat_long, traits: [:with_lat_long]
    factory :site_with_audio_recordings, traits: [:with_lat_long, :with_audio_recordings]
  end
end
