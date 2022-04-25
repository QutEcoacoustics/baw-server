# frozen_string_literal: true

# == Schema Information
#
# Table name: analysis_jobs
#
#  id                           :integer          not null, primary key
#  annotation_name              :string
#  custom_settings              :text             not null
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
#  saved_search_id              :integer          not null
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
require 'support/resque_helpers'
require 'aasm/rspec'

describe AnalysisJob, type: :model do
  it 'has a valid factory' do
    expect(create(:analysis_job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id).optional }

  it { is_expected.to validate_presence_of(:name) }

  it 'is invalid without a name' do
    expect(build(:analysis_job, name: nil)).not_to be_valid
  end

  it 'ensures the name is no more than 255 characters' do
    test_string = 'a' * 256
    expect(build(:analysis_job, name: test_string)).not_to be_valid
    expect(build(:analysis_job, name: test_string[0..-2])).to be_valid
  end

  it 'ensures name is unique (case-insensitive)' do
    create(:analysis_job, name: 'There ain\'t room enough in this town for two of us sonny!')
    aj2 = build(:analysis_job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!')

    expect(aj2).not_to be_valid
    expect(aj2).not_to be_valid
    expect(aj2.errors[:name].size).to eq(1)
  end

  it 'fails validation when script is nil' do
    test_item = build(:analysis_job)
    test_item.script = nil

    expect(subject).not_to be_valid

    expect(subject.errors[:script]).to have(1).items
    expect(subject.errors[:script].to_s).to match(/must exist/)
  end

  it { is_expected.to validate_presence_of(:custom_settings) }

  it 'is invalid without a custom_settings' do
    expect(build(:analysis_job, custom_settings: nil)).not_to be_valid
  end

  it 'is invalid without a script' do
    aj = build(:analysis_job, script_id: nil)
    aj.script = nil
    expect(aj).not_to be_valid
  end

  it 'is invalid without a saved_search' do
    expect(build(:analysis_job, saved_search: nil)).not_to be_valid
  end

  describe 'state machine' do
    let(:analysis_job) {
      create(:analysis_job)
    }

    it 'defines the initialize_workflow event (allows before_save->new)' do
      analysis_job = build(:analysis_job, overall_status_modified_at: nil)

      expect(analysis_job).to transition_from(:before_save).to(:new).on_event(:initialize_workflow)
    end

    it 'can\'t transition to new twice' do
      analysis_job = build(:analysis_job, overall_status_modified_at: nil)

      analysis_job.initialize_workflow

      expect(analysis_job).not_to allow_event(:initialize_workflow)
    end

    it 'calls initialize_workflow when created' do
      analysis_job = build(:analysis_job)

      allow(analysis_job).to receive(:save!).and_call_original
      allow(analysis_job).to receive(:initialize_workflow).and_call_original

      analysis_job.save!

      expect(analysis_job).to have_received(:save!)
      expect(analysis_job).to have_received(:initialize_workflow).once
    end

    it 'defines the prepare event' do
      allow(analysis_job).to receive(:process!).and_return(nil)

      expect(analysis_job).to transition_from(:new).to(:preparing).on_event(:prepare)
    end

    it 'defines the process event' do
      allow(analysis_job).to receive(:all_job_items_completed?).and_return(false)
      expect(analysis_job).to transition_from(:preparing).to(:processing).on_event(:process)
    end

    it 'defines the process event - and complete if all items are done!' do
      allow(analysis_job).to receive(:all_job_items_completed?).and_return(true)
      expect(analysis_job).to transition_from(:preparing).to(:completed).on_event(:process)
    end

    it 'defines the suspend event' do
      expect(analysis_job).to transition_from(:processing).to(:suspended).on_event(:suspend)
    end

    it 'defines the resume event' do
      expect(analysis_job).to transition_from(:suspended).to(:processing).on_event(:resume)
    end

    it 'defines the complete event' do
      expect(analysis_job).to transition_from(:processing).to(:completed).on_event(:complete)
    end

    it 'defines the retry event - which does not work if all items successful' do
      allow(analysis_job).to receive(:are_any_job_items_failed?).and_return(false)
      allow(analysis_job).to receive(:retry_job).and_return(nil)
      expect(analysis_job).not_to allow_event(:retry)
    end

    it 'defines the retry event' do
      allow(analysis_job).to receive(:are_any_job_items_failed?).and_return(true)
      expect(analysis_job).to transition_from(:completed).to(:processing).on_event(:retry)
    end
  end
end
