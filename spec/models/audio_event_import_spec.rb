# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_event_imports
#
#  id          :bigint           not null, primary key
#  deleted_at  :datetime
#  description :text
#  files       :jsonb
#  name        :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  creator_id  :integer
#  deleter_id  :integer
#  updater_id  :integer
#
describe AudioEventImport, type: :model do
  subject { build(:audio_event_import) }

  it 'has a valid factory' do
    expect(create(:audio_event_import)).to be_valid
  end

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id).optional }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id).optional }

  it { is_expected.to have_many(:audio_events) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_least(2) }
end
