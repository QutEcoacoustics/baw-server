# frozen_string_literal: true

# == Schema Information
#
# Table name: scripts
#
#  id                             :integer          not null, primary key
#  analysis_action_params         :json
#  analysis_identifier            :string           not null
#  description                    :string
#  executable_command             :text             not null
#  executable_settings            :text             not null
#  executable_settings_media_type :string(255)      default("text/plain")
#  name                           :string           not null
#  verified                       :boolean          default(FALSE)
#  version                        :decimal(4, 2)    default(0.1), not null
#  created_at                     :datetime         not null
#  creator_id                     :integer          not null
#  group_id                       :integer
#
# Indexes
#
#  index_scripts_on_creator_id  (creator_id)
#  index_scripts_on_group_id    (group_id)
#
# Foreign Keys
#
#  scripts_creator_id_fk  (creator_id => users.id)
#  scripts_group_id_fk    (group_id => scripts.id)
#
describe Script, type: :model do
  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:settings_file).
  #                 allowing('text/plain').
  #                 rejecting('text/plain1', 'image/gif', 'image/jpeg', 'image/png', 'text/xml', 'image/abc', 'some_image/png', 'text2/plain') }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }

  it 'has a valid factory' do
    s = create(:script)

    expect(s).to be_valid
  end

  it { is_expected.to have_many(:analysis_jobs) }

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }

  it 'should validate the existence of a creator' do
    expect(build(:script, creator_id: nil)).not_to be_valid
  end

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:analysis_identifier) }
  it { should validate_presence_of(:executable_command) }
  it { should validate_presence_of(:executable_settings) }
  it { should validate_presence_of(:executable_settings_media_type) }

  it { should validate_length_of(:name).is_at_least(2) }
  it { should validate_length_of(:analysis_identifier).is_at_least(2) }
  it { should validate_length_of(:executable_command).is_at_least(2) }
  it { should validate_length_of(:executable_settings).is_at_least(2) }
  it { should validate_length_of(:executable_settings_media_type).is_at_least(2) }

  it 'should validate version increasing on creation' do
    original = create(:script, version: 1.0)

    new = build(:script, group_id: original.group_id, version: 0.5)

    expect(new).not_to be_valid
  end

  it 'should ensure the group_id is the same as the initial id' do
    script = create(:script, version: 1.0)

    expect(script.group_id).to be script.id
  end

  describe 'latest and earliest versions' do
    let!(:three_versions) {
      first = create(:script, version: 1.0, id: 999)
      [
        first,
        create(:script, version: 1.5, group_id: first.id),
        create(:script, version: 1.6, group_id: first.id)
      ]
    }

    it 'when there\'s only item in the group, it is both latest and earliest' do
      script = create(:script)
      expect(script.is_last_version?).to be true
      expect(script.is_first_version?).to be true
    end

    it 'shows when a script is the latest version' do
      expect(three_versions[0].is_last_version?).to be false
      expect(three_versions[1].is_last_version?).to be false
      expect(three_versions[2].is_last_version?).to be true
    end

    it 'shows when a script is the earliest version' do
      expect(three_versions[0].is_first_version?).to be true
      expect(three_versions[1].is_first_version?).to be false
      expect(three_versions[2].is_first_version?).to be false
    end
  end
end
