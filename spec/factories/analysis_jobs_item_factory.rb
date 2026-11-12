# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs_items
#
#  id                                                                                                                                                            :bigint           not null, primary key
#  attempts(Number of times this job item has been attempted)                                                                                                    :integer          default(0), not null
#  cancel_started_at                                                                                                                                             :datetime
#  error(Error message if this job item failed)                                                                                                                  :text
#  finished_at                                                                                                                                                   :datetime
#  import_success(Did importing audio events succeed?)                                                                                                           :boolean
#  queued_at                                                                                                                                                     :datetime
#  result(Result of this job item)                                                                                                                               :enum
#  status(Current status of this job item)                                                                                                                       :enum             default("new"), not null
#  transition(The pending transition to apply to this item. Any high-latency action should be done via transition and on a worker rather than in a web request.) :enum
#  used_memory_bytes(Memory used by this job item)                                                                                                               :bigint
#  used_walltime_seconds(Walltime used by this job item)                                                                                                         :integer
#  work_started_at                                                                                                                                               :datetime
#  created_at                                                                                                                                                    :datetime         not null
#  analysis_job_id                                                                                                                                               :integer          not null
#  audio_recording_id                                                                                                                                            :integer          not null
#  queue_id                                                                                                                                                      :string(255)
#  script_id(Script used for this item)                                                                                                                          :integer          not null
#
# Indexes
#
#  index_analysis_jobs_items_are_unique             (analysis_job_id,script_id,audio_recording_id) UNIQUE
#  index_analysis_jobs_items_on_analysis_job_id     (analysis_job_id)
#  index_analysis_jobs_items_on_audio_recording_id  (audio_recording_id)
#  index_analysis_jobs_items_on_script_id           (script_id)
#  queue_id_uidx                                    (queue_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (analysis_job_id => analysis_jobs.id) ON DELETE => cascade
#  fk_rails_...  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  fk_rails_...  (script_id => scripts.id)
#
FactoryBot.define do
  factory :analysis_jobs_item do
    analysis_job
    audio_recording
    script

    queue_id { SecureRandom.uuid }

    # Handled by workflow
    #status { 'new' }
    #queue_id  { SecureRandom.uuid }
  end
end
