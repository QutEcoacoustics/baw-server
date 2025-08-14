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
require 'support/resque_helpers'

describe AnalysisJobsItem do
  let!(:analysis_jobs_item) { create(:analysis_jobs_item) }

  it 'has a valid factory' do
    expect(create(:analysis_jobs_item)).to be_valid
  end

  it 'cannot be created when status is not new' do
    expect {
      create(:analysis_jobs_item, status: nil)
    }.to raise_error(AASM::NoDirectAssignmentError, /direct assignment of AASM column has been disabled/)
  end

  it 'created_at should be set by rails' do
    item = create(:analysis_jobs_item)
    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true

    item.reload

    expect(item.created_at).not_to be_blank
    expect(item.valid?).to be true
  end

  it { is_expected.to belong_to(:analysis_job) }
  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:script) }

  # it { should validate_presence_of(:status) }
  #
  # it { should validate_length_of(:status).is_at_least(2).is_at_most(255) }

  it { is_expected.to validate_uniqueness_of(:queue_id) }

  it 'does not allow dates greater than now for created_at' do
    analysis_jobs_item.created_at = 1.day.from_now
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for queued_at' do
    analysis_jobs_item.queued_at = 1.day.from_now
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for work_started_at' do
    analysis_jobs_item.work_started_at = 1.day.from_now
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for finished_at' do
    analysis_jobs_item.finished_at = 1.day.from_now
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'allows large numbers for used_memory_bytes' do
    analysis_jobs_item.used_memory_bytes = 128.gigabytes
    expect(analysis_jobs_item).to be_valid

    expect(analysis_jobs_item.save).to be true
  end

  it_behaves_like 'cascade deletes for', :analysis_jobs_item, {
    audio_event_import_files: {
      audio_events: {
        taggings: nil,
        comments: nil,
        verifications: nil
      }
    }
  } do
    create_entire_hierarchy
  end
end
