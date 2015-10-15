require 'rails_helper'

describe Permission, type: :model do
  subject { FactoryGirl.build(:read_permission, project: FactoryGirl.create(:project)) }

  it { is_expected.to belong_to(:creator).class_name('User').with_foreign_key(:creator_id).inverse_of(:created_permissions) }
  it { is_expected.to belong_to(:updater).class_name('User').with_foreign_key(:updater_id).inverse_of(:updated_permissions) }
  it { is_expected.to belong_to(:project).inverse_of(:permissions) }
  it { is_expected.to belong_to(:user).inverse_of(:permissions) }

  it { is_expected.to validate_presence_of(:level) }

  # .with_predicates(true).with_multiple(false)
  it { is_expected.to enumerize(:level).in(*Permission::AVAILABLE_LEVELS) }

  # We discourage using validate_inclusion_of with boolean columns.
  # In fact, there is never a case where a boolean column will be
  # anything but true, false, or nil, as ActiveRecord will type-cast
  # an incoming value to one of these three values.
  # That means there isn't any way we can refute this logic in a test.
  # Hence, this will produce a warning:
  # it { should validate_inclusion_of(:imported).in_array([true, false]) }
  # The only case where validate_inclusion_of could be appropriate is for
  # ensuring that a boolean column accepts nil, but we recommend using allow_value instead

  it { is_expected.not_to allow_value(nil).for(:allow_anonymous) }
  it { is_expected.not_to allow_value(nil).for(:allow_logged_in) }

  context 'special tests' do
    let(:user) { FactoryGirl.create(:user) }
    let(:project) { FactoryGirl.create(:project, creator: user) }

    context 'enforces exactly one permission setting per project' do
      context 'fails with' do
        it 'no settings' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: nil, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end

        it 'allow_anonymous and allow_logged_in' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: nil, allow_logged_in: true, allow_anonymous: true)
          expect(permission).not_to be_valid
        end

        it 'user and allow_anonymous' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: true)
          expect(permission).not_to be_valid
        end

        it 'user and allow_logged_in' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: user, allow_logged_in: true, allow_anonymous: false)
          expect(permission).not_to be_valid
        end

        it 'user and allow_anonymous and allow_logged_in' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: user, allow_logged_in: true, allow_anonymous: true)
          expect(permission).not_to be_valid
        end
        it 'user at invalid level' do
          permission = FactoryGirl.build(:permission, level: 'something_wrong', creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end
        it 'user at nil level' do
          permission = FactoryGirl.build(:permission, level: nil, creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end
      end
      context 'succeeds with' do
        it 'user at reader level' do
          permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
        it 'user at writer level' do
          permission = FactoryGirl.build(:permission, level: 'writer', creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
      it 'user at owner level' do
          permission = FactoryGirl.build(:permission, level: 'owner', creator: user,
                                         user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
      end
    end

    context 'enforces levels for logged_in' do
      it 'fails for invalid level value' do
        permission = FactoryGirl.build(:permission, level: 'something_wrong', creator: user,
                                       user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
      it 'fails for nil level' do
        permission = FactoryGirl.build(:permission, level: nil, creator: user,
                                       user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
      it 'succeeds for reader level' do
        permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                       user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).to be_valid
      end
      it 'succeeds for writer level' do
        permission = FactoryGirl.build(:permission, level: 'writer', creator: user,
                                       user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).to be_valid
      end
      it 'fails for owner level' do
        permission = FactoryGirl.build(:permission, level: 'owner', creator: user,
                                       user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
    end

    context 'enforces levels for anonymous' do
      it 'fails for invalid level value' do
        permission = FactoryGirl.build(:permission, level: 'something_wrong', creator: user,
                                       user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'fails for nil level' do
        permission = FactoryGirl.build(:permission, level: nil, creator: user,
                                       user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'succeeds for reader level' do
        permission = FactoryGirl.build(:permission, level: 'reader', creator: user,
                                       user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).to be_valid
      end
      it 'fails for writer level' do
        permission = FactoryGirl.build(:permission, level: 'writer', creator: user,
                                       user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'fails for owner level' do
        permission = FactoryGirl.build(:permission, level: 'owner', creator: user,
                                       user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
    end

  end
end
