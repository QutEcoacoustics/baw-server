# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs_items
#
#  id                 :integer          not null, primary key
#  cancel_started_at  :datetime
#  completed_at       :datetime
#  queued_at          :datetime
#  status             :string(255)      default("new"), not null
#  work_started_at    :datetime
#  created_at         :datetime         not null
#  analysis_job_id    :integer          not null
#  audio_recording_id :integer          not null
#  queue_id           :string(255)
#
# Indexes
#
#  index_analysis_jobs_items_on_analysis_job_id     (analysis_job_id)
#  index_analysis_jobs_items_on_audio_recording_id  (audio_recording_id)
#  queue_id_uidx                                    (queue_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (analysis_job_id => analysis_jobs.id)
#  fk_rails_...  (audio_recording_id => audio_recordings.id)
#
FactoryBot.define do
  factory :analysis_jobs_item do
    analysis_job
    audio_recording

    queue_id { SecureRandom.uuid }

    # Handled by workflow
    #status "new"
    #queue_id  { SecureRandom.uuid }
  end
end
