# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                                                                                                                                                                                      :integer          not null, primary key
#  amend_count(Count of amendments)                                                                                                                                                        :integer          default(0), not null
#  deleted_at                                                                                                                                                                              :datetime
#  description                                                                                                                                                                             :text
#  filter(API filter to include recordings in this job. If blank then all recordings are included.)                                                                                        :jsonb
#  name                                                                                                                                                                                    :string           not null
#  ongoing(If true the filter for this job will be evaluated after a harvest. If more items are found the job will move to the processing stage if needed and process the new recordings.) :boolean          default(FALSE), not null
#  overall_count                                                                                                                                                                           :integer          not null
#  overall_data_length_bytes                                                                                                                                                               :bigint           default(0), not null
#  overall_duration_seconds                                                                                                                                                                :decimal(14, 4)   not null
#  overall_status                                                                                                                                                                          :string           not null
#  overall_status_modified_at                                                                                                                                                              :datetime         not null
#  resume_count(Count of resumptions)                                                                                                                                                      :integer          default(0), not null
#  retry_count(Count of retries)                                                                                                                                                           :integer          default(0), not null
#  started_at                                                                                                                                                                              :datetime
#  suspend_count(Count of suspensions)                                                                                                                                                     :integer          default(0), not null
#  system_job(If true this job is automatically run and not associated with a single project. We can have multiple system jobs.)                                                           :boolean          default(FALSE), not null
#  created_at                                                                                                                                                                              :datetime
#  updated_at                                                                                                                                                                              :datetime
#  creator_id                                                                                                                                                                              :integer          not null
#  deleter_id                                                                                                                                                                              :integer
#  project_id(Project this job is associated with. This field simply influences which jobs are shown on a project page.)                                                                   :integer
#  updater_id                                                                                                                                                                              :integer
#
# Indexes
#
#  analysis_jobs_name_uidx            (name,creator_id) UNIQUE
#  index_analysis_jobs_on_creator_id  (creator_id)
#  index_analysis_jobs_on_deleter_id  (deleter_id)
#  index_analysis_jobs_on_project_id  (project_id)
#  index_analysis_jobs_on_updater_id  (updater_id)
#
# Foreign Keys
#
#  analysis_jobs_creator_id_fk  (creator_id => users.id)
#  analysis_jobs_deleter_id_fk  (deleter_id => users.id)
#  analysis_jobs_updater_id_fk  (updater_id => users.id)
#  fk_rails_...                 (project_id => projects.id) ON DELETE => cascade
#
FactoryBot.define do
  factory :analysis_job do
    sequence(:name) { |n| "job name #{n}" }
    sequence(:description) { |n| "job description #{n}" }

    project

    creator
    transient do
      scripts_count { 2 }
    end

    after(:build) do |analysis_job, context|
      # allow
      next if analysis_job.scripts.present?

      scripts = create_list(:script, context.scripts_count)
      analysis_job.scripts = scripts
    end

    overall_count { 1 }
    overall_duration_seconds  { 60 }
    overall_data_length_bytes { 1024 }

    started_at { Time.zone.now }

    # should be set by the state machine
    #overall_status_modified_at { Time.zone.now }

    filter { {} }
  end
end
