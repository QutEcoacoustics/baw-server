# == Schema Information
#
# Table name: exports
#
#  id                                                     :bigint           not null, primary key
#  download_count                                         :integer          default(0)
#  error(User visible error message if the export failed) :text
#  expires_at                                             :datetime
#  export_type                                            :string(16)       not null
#  filter                                                 :jsonb            not null
#  finished_at                                            :datetime
#  name                                                   :string
#  obfuscate_locations                                    :boolean
#  options(Additional options for the export)             :jsonb
#  purged                                                 :boolean
#  started_at                                             :datetime
#  status                                                 :enum             default("pending"), not null
#  created_at                                             :datetime         not null
#  updated_at                                             :datetime         not null
#  creator_id                                             :bigint           not null
#  project_id                                             :bigint
#
# Indexes
#
#  index_exports_on_creator_id  (creator_id)
#  index_exports_on_project_id  (project_id)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#
require 'rails_helper'

describe Export do
  subject { build(:export, :camtrap_dp) }

  it 'has a valid camtrap_dp factory without a file' do
    expect(subject).to be_valid
    expect(subject).to be_export_type_camtrap_dp
    expect(subject.file).not_to be_attached
  end

  it 'has a valid camtrap_dp factory with a zip file' do
    expect(create(:export, :camtrap_dp, :with_zip_file)).to be_valid
  end

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:project).optional(true) }

  it 'has a download count of 0 by default' do
    expect(subject.download_count).to eq(0)
  end

  it 'has a status of pending by default' do
    expect(subject.status).to eq('pending')
  end

  it 'accepts an attached zip file' do
    export = build(:export, :camtrap_dp, :with_zip_file)

    expect(export.file).to be_attached
    expect(export).to be_valid
  end

  it 'validates that the file is a zip file' do
    export = build(:export, :camtrap_dp, :with_zip_file)
    export.file.blob.update(content_type: 'application/pdf')

    expect(export).not_to be_valid
    expect(export.errors[:file]).to include('must be a zip file')
  end

  it 'validates camtrap_dp options using the contract' do
    export = build(:export, :camtrap_dp, creator: create(:user), options: { project_capture_method: ['continuous'] })

    expect(export).to be_valid
  end

  it 'is invalid when camtrap_dp options fail the contract' do
    export = build(:export, :camtrap_dp, creator: create(:user), options: { project_capture_method: ['invalid'] })

    expect(export).not_to be_valid
    expect(export.errors[:options]).to include(
      'project_capture_method.0 must be one of: activityDetection, continuous, recordingSchedule'
    )
  end

  context 'when generating a camtrap_dp export' do
    create_entire_hierarchy

    let(:test_export_with_options_and_filter) {
      options = {
        contributors: [{ title: 'Alice', path: 'http://www.test' }],
        project_capture_method: ['continuous', 'recordingSchedule'],
        project_sampling_design: 'systematicRandom',
        emit_project_license: true,
        forced_timezone: nil
      }

      filter = { and: [{ 'sites.id': { in: [site.id] } }] }

      create(:export, :camtrap_dp, options: options, filter: filter)
    }
  end
end
