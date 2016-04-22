require 'rails_helper'
require 'helpers/resque_helper'

describe AnalysisJobsItem, type: :model do
  let!(:analysis_jobs_item) { create(:analysis_jobs_item) }

  it 'has a valid factory' do
    expect(create(:analysis_jobs_item)).to be_valid
  end

  it 'cannot be created when status is not new' do
    expect {
      create(:analysis_jobs_item, status: nil)
    }.to raise_error
  end

  it 'created_at should be set by rails' do
    item = create(:analysis_jobs_item)
    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true

    item.reload

    expect(item.created_at).to_not be_blank
    expect(item.valid?).to be true
  end


  it { is_expected.to belong_to(:analysis_job) }
  it { is_expected.to belong_to(:audio_recording) }


  # it { should validate_presence_of(:status) }
  #
  # it { should validate_length_of(:status).is_at_least(2).is_at_most(255) }

  it { should validate_uniqueness_of(:queue_id) }

  it {
    is_expected.to enumerize(:status)
                       .in(*AnalysisJobsItem::AVAILABLE_ITEM_STATUS_SYMBOLS)
                       .with_default(:new)
  }

  it 'does not allow dates greater than now for created_at' do
    analysis_jobs_item.created_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for queued_at' do
    analysis_jobs_item.queued_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for work_started_at' do
    analysis_jobs_item.work_started_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  it 'does not allow dates greater than now for completed_at' do
    analysis_jobs_item.completed_at = Time.zone.now + 1.day
    expect(analysis_jobs_item).not_to be_valid
  end

  describe 'analysis_jobs_item state transitions' do
    [
        [:new, :new, true],
        [:new, :queued, :queued_at],
        [:new, :working, false],
        [:new, :successful, false],
        [:new, :failed, false],
        [:new, :timed_out, false],
        [:new, :cancelled, :completed_at],
        [:new, nil, false],
        [:queued, :new, false],
        [:queued, :queued, true],
        [:queued, :working, :work_started_at],
        [:queued, :successful, false],
        [:queued, :failed, false],
        [:queued, :timed_out, false],
        [:queued, :cancelled, :completed_at],
        [:queued, nil, false],
        [:working, :new, false],
        [:working, :queued, false],
        [:working, :working, true],
        [:working, :successful, :completed_at],
        [:working, :failed, :completed_at],
        [:working, :timed_out, :completed_at],
        [:working, :cancelled, :completed_at],
        [:working, nil, false],
        [:successful, :new, false],
        [:successful, :queued, false],
        [:successful, :working, false],
        [:successful, :successful, true],
        [:successful, :failed, false],
        [:successful, :timed_out, false],
        [:successful, :cancelled, false],
        [:successful, nil, false],
        [:failed, :new, false],
        [:failed, :queued, false],
        [:failed, :working, false],
        [:failed, :successful, false],
        [:failed, :failed, true],
        [:failed, :timed_out, false],
        [:failed, :cancelled, false],
        [:failed, nil, false],
        [:timed_out, :new, false],
        [:timed_out, :queued, false],
        [:timed_out, :working, false],
        [:timed_out, :successful, false],
        [:timed_out, :failed, false],
        [:timed_out, :timed_out, true],
        [:timed_out, :cancelled, false],
        [:timed_out, nil, false],
        [:cancelled, :new, false],
        [:cancelled, :queued, false],
        [:cancelled, :working, false],
        [:cancelled, :successful, false],
        [:cancelled, :failed, false],
        [:cancelled, :timed_out, false],
        [:cancelled, :cancelled, true],
        [:cancelled, nil, false],
        [nil, :new, false],
        [nil, :queued, false],
        [nil, :working, false],
        [nil, :successful, false],
        [nil, :failed, false],
        [nil, :timed_out, false],
        [nil, :cancelled, false],
        # if all the other combinations hold true this case will never happen anyway
        [nil, nil, true]
    ].each do |test_case|

      it "tests state transition #{ test_case[0].to_s }→#{ test_case[1].to_s }" do

        analysis_jobs_item.write_attribute(:status, test_case[0])

        if test_case[2]
          if test_case[2].is_a? Symbol
            first_date = analysis_jobs_item[test_case[2]]
          end

          analysis_jobs_item.status = test_case[1]

          expect(analysis_jobs_item.status == test_case[1]).to be true
          expect(analysis_jobs_item[test_case[2]]).to not_be first_date if first_date
        else
          expect {
            analysis_jobs_item.status = test_case[1]
          }.to raise_error

        end
      end
    end

  end
end