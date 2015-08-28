require 'spec_helper'

describe AnalysisJob, type: :model do
  it 'has a valid factory' do
    expect(create(:analysis_job)).to be_valid
  end
  #it {should have_many(:analysis_items)}

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

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
    expect(build(:analysis_job, script_id: nil)).not_to be_valid
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

      aj = build(:analysis_job, creator: user, script: s, saved_search: ss, )

      result = aj.saved_search_items_extract(user)

      # TODO compare to entire expected payload hash

      expect(result.size).to eq(1)
      expect(result[0].is_a?(Hash)).to be_truthy
      expect(result[0][:command_format]).to eq(aj.script.executable_command)

    end

    it 'enqueues and processes payloads' do
      pending
    end

  end

end