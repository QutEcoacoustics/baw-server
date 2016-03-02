require 'rails_helper'
require 'helpers/resque_helper'

describe AnalysisJob, type: :model do
  it 'has a valid factory' do
    expect(create(:analysis_job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  # .with_predicates(true).with_multiple(false)
  it { is_expected.to enumerize(:overall_status).in(*AnalysisJob::AVAILABLE_JOB_STATUS) }

  it { is_expected.to validate_presence_of(:name) }
  it 'is invalid without a name' do
    expect(build(:analysis_job, name: nil)).not_to be_valid
  end
  it 'should ensure the name is no more than 255 characters' do
    test_string = 'a' * 256
    expect(build(:analysis_job, name: test_string)).not_to be_valid
    expect(build(:analysis_job, name: test_string[0..-2])).to be_valid
  end
  it 'should ensure name is unique  (case-insensitive)' do
    create(:analysis_job, name: 'There ain\'t room enough in this town for two of us sonny!')
    as2 = build(:analysis_job, name: 'THERE AIN\'T ROOM ENOUGH IN THIS TOWN FOR TWO OF US SONNY!')
    expect(as2).not_to be_valid
    expect(as2.valid?).to be_falsey
    expect(as2.errors[:name].size).to eq(1)
  end

  it 'fails validation when script is nil' do
    test_item = FactoryGirl.build(:analysis_job)
    test_item.script = nil

    expect(subject.valid?).to be_falsey
    expect(subject.errors[:script].size).to eq(1)
    expect(subject.errors[:script].to_s).to match(/must exist as an object or foreign key/)
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

  context 'job items' do

    it 'extracts the correct payloads' do
      project_1 = create(:project)
      user = project_1.creator
      site_1 = create(:site, projects: [project_1], creator: user)

      create(:audio_recording, site: site_1, creator: user, uploader: user)

      project_2 = create(:project, creator: user)
      site_2 = create(:site, projects: [project_2], creator: user)
      audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

      ss = create(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})
      s = create(:script, creator: user, verified: true)

      aj = create(:analysis_job, creator: user, script: s, saved_search: ss)

      payload = aj.create_payload(audio_recording_2)
      result = aj.begin_work(user)
      
      # ensure result is as expected
      expect(result.size).to eq(1)
      expect(result[0].is_a?(Hash)).to be_truthy
      expect(result[0][:payload][:command_format]).to eq(aj.script.executable_command)
      expect(result[0][:error]).to be_blank
      expect(result[0][:payload]).to eq(payload)
      expect(result[0][:result].is_a?(String)).to be_truthy
      expect(result[0][:result].size).to eq(32)
    end

    it 'enqueues and processes payloads' do
      project_1 = create(:project)
      user = project_1.creator
      site_1 = create(:site, projects: [project_1], creator: user)

      create(:audio_recording, site: site_1, creator: user, uploader: user)

      project_2 = create(:project, creator: user)
      site_2 = create(:site, projects: [project_2], creator: user)
      audio_recording_2 = create(:audio_recording, site: site_2, creator: user, uploader: user)

      ss = create(:saved_search, creator: user, stored_query: {id: {in: [audio_recording_2.id]}})
      s = create(:script, creator: user, verified: true)

      aj = create(:analysis_job, creator: user, script: s, saved_search: ss)

      result = aj.begin_work(user)

      queue_name = Settings.actions.analysis.queue

      expect(Resque.size(queue_name)).to eq(1)
      worker, job = emulate_resque_worker(queue_name, false, true)
      expect(Resque.size(queue_name)).to eq(0)

      #expect(BawWorkers::ResqueApi.jobs.inspect).to eq(1)


    end

  end

end