# frozen_string_literal: true

# == Schema Information
#
# Table name: projects
#
#  id                      :integer          not null, primary key
#  allow_audio_upload      :boolean          default(FALSE)
#  allow_original_download :string
#  deleted_at              :datetime
#  description             :text
#  image_content_type      :string
#  image_file_name         :string
#  image_file_size         :integer
#  image_updated_at        :datetime
#  name                    :string           not null
#  notes                   :text
#  urn                     :string
#  created_at              :datetime
#  updated_at              :datetime
#  creator_id              :integer          not null
#  deleter_id              :integer
#  updater_id              :integer
#
# Indexes
#
#  index_projects_on_creator_id  (creator_id)
#  index_projects_on_deleter_id  (deleter_id)
#  index_projects_on_updater_id  (updater_id)
#  projects_name_uidx            (name) UNIQUE
#
# Foreign Keys
#
#  projects_creator_id_fk  (creator_id => users.id)
#  projects_deleter_id_fk  (deleter_id => users.id)
#  projects_updater_id_fk  (updater_id => users.id)
#
FactoryBot.define do
  factory :project do
    sequence(:name) { |n| "gen_project#{n}" }
    sequence(:description) { |n| "project description #{n}" }
    sequence(:urn) { |n| "urn:project:example.org/project/#{n}" }
    sequence(:notes) { |n| "note number #{n}" }

    creator

    trait :image do
      image_file { fixture_file_upload(Rails.root.join('public', 'images', 'user', 'user_spanhalf.png'), 'image/png') }
    end

    trait :with_sites do
      transient do
        site_count { 1 }
      end
      after(:create) do |project, evaluator|
        raise 'Creator was blank' if evaluator.creator.blank?

        evaluator.site_count.times do
          project.sites << FactoryBot.create(:site_with_audio_recordings, creator: evaluator.creator)
        end
      end
    end

    trait :with_saved_searches do
      transient do
        saved_search_count { 1 }
      end
      after(:create) do |project, evaluator|
        raise 'Creator was blank' if evaluator.creator.blank?

        evaluator.saved_search_count.times do
          project.saved_searches << FactoryBot.create(:saved_search_with_analysis_jobs, creator: evaluator.creator)
        end
      end
    end

    factory :project_with_sites, traits: [:with_sites]
    factory :project_with_sites_and_saved_searches, traits: [:with_sites, :with_saved_searches]
  end
end
