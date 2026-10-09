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
  subject { build(:export) }

  it 'has a valid factory' do
    expect(subject).to be_valid
  end

  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:project).optional(true) }

  it 'has a download count of 0 by default' do
    expect(subject.download_count).to eq(0)
  end

  it 'has a status of pending by default' do
    expect(subject.status).to eq('pending')
  end
end
