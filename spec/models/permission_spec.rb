require 'spec_helper'

describe Permission, :type => :model do
  #pending "add some examples to (or delete) #{__FILE__}"

  let(:error_type) { 'ActiveRecord::RecordNotUnique'.constantize }
  let(:error_msg) { 'A permission can store only one of \'anonymous_user\' \(set to ' }

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }

  it 'should be enumerized' do
    is_expected.to enumerize(:level).in('writer', 'reader', 'owner')
  end

  context 'is invalid' do
    it 'has no attributes' do
      expect { Permission.create }.to raise_error(error_type, /#{error_msg}/)
    end

    it 'has invalid level' do
      write_permission = FactoryGirl.create(:write_permission)
      expect {
        Permission.create(level: 'blah_blah', project_id: write_permission.project.id, user_id: write_permission.user.id)
      }.to raise_error(error_type, /#{error_msg}/)
    end
  end

end
