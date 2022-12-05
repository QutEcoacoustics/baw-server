# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                           :integer          not null, primary key
#  custom_settings              :text
#  deleted_at                   :datetime
#  description                  :text
#  name                         :string           not null
#  overall_count                :integer          not null
#  overall_data_length_bytes    :bigint           default(0), not null
#  overall_duration_seconds     :decimal(14, 4)   not null
#  overall_progress             :json             not null
#  overall_progress_modified_at :datetime         not null
#  overall_status               :string           not null
#  overall_status_modified_at   :datetime         not null
#  started_at                   :datetime
#  created_at                   :datetime
#  updated_at                   :datetime
#  creator_id                   :integer          not null
#  deleter_id                   :integer
#  saved_search_id              :integer
#  script_id                    :integer          not null
#  updater_id                   :integer
#
# Indexes
#
#  analysis_jobs_name_uidx                 (name,creator_id) UNIQUE
#  index_analysis_jobs_on_creator_id       (creator_id)
#  index_analysis_jobs_on_deleter_id       (deleter_id)
#  index_analysis_jobs_on_saved_search_id  (saved_search_id)
#  index_analysis_jobs_on_script_id        (script_id)
#  index_analysis_jobs_on_updater_id       (updater_id)
#
# Foreign Keys
#
#  analysis_jobs_creator_id_fk       (creator_id => users.id)
#  analysis_jobs_deleter_id_fk       (deleter_id => users.id)
#  analysis_jobs_saved_search_id_fk  (saved_search_id => saved_searches.id)
#  analysis_jobs_script_id_fk        (script_id => scripts.id)
#  analysis_jobs_updater_id_fk       (updater_id => users.id)
#
FactoryBot.define do
  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:custom_settings) { |n| "custom settings #{n}" }
    sequence(:description) { |n| "job description #{n}" }

    creator
    saved_search
    script

    overall_progress { { queued: 1, working: 0, success: 0, failed: 0, total: 1 }.to_json }
    overall_count { 1 }
    overall_duration_seconds  { 60 }
    overall_data_length_bytes { 1024 }

    started_at { Time.zone.now }

    # should be set by the workflow
    #overall_status_modified_at { Time.zone.now }
    overall_progress_modified_at { Time.zone.now }

    factory :analysis_job_with_valid_saved_search do
      association :saved_search, factory: :saved_search_with_projects
    end
  end
end
