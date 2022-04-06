# frozen_string_literal: true

# == Schema Information
#
# Table name: harvests
#
#  id              :bigint           not null, primary key
#  mappings        :jsonb
#  state           :string
#  streaming       :boolean
#  upload_password :string
#  upload_user     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  creator_id      :integer
#  project_id      :integer          not null
#  updater_id      :integer
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (updater_id => users.id)
#
RSpec.describe Harvest, type: :model do
  subject { build(:harvest) }

  it 'has a valid factory' do
    expect(create(:harvest)).to be_valid
  end

  it { is_expected.to belong_to(:project) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional(true) }

  it 'encodes the mappings column as jsonb' do
    expect(Harvest.columns_hash['mappings'].type).to eq(:jsonb)
  end

  it 'can generate a upload url' do
    expect(subject.upload_url).to eq "sftp://#{Settings.upload_service.host}:#{Settings.upload_service}"
  end
end
