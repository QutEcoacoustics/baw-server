require 'spec_helper'

describe Permission, :type => :model do
  #pending "add some examples to (or delete) #{__FILE__}"

  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }

  it 'should be enumerized' do
    is_expected.to enumerize(:level).in('writer', 'reader', 'owner')
  end

  context 'is invalid' do
    it 'has no attributes' do
      error_msg = "Validation failed: Project must exist as an object or foreign key for Permission, Project can't be blank, Creator must exist as an object or foreign key for Permission, Creator can't be blank, Level can't be blank, User must be set if anonymous user and logged in user are false"
      expect { Permission.create! }.to raise_error(ActiveRecord::RecordInvalid, error_msg)
    end

    it 'has invalid level' do
      write_permission = FactoryGirl.create(:write_permission)
      new_user = FactoryGirl.create(:confirmed_user)

      error_msg = 'Validation failed: Level is not included in the list'
      expect {
        Permission.create!(level: 'blah_blah', project: write_permission.project, user: new_user, creator:new_user)
      }.to raise_error(ActiveRecord::RecordInvalid, error_msg)
    end
  end

end
