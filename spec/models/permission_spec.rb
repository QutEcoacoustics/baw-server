# frozen_string_literal: true

# == Schema Information
#
# Table name: permissions
#
#  id              :integer          not null, primary key
#  allow_anonymous :boolean          default(FALSE), not null
#  allow_logged_in :boolean          default(FALSE), not null
#  level           :string           not null
#  created_at      :datetime
#  updated_at      :datetime
#  creator_id      :integer          not null
#  project_id      :integer          not null
#  updater_id      :integer
#  user_id         :integer
#
# Indexes
#
#  index_permissions_on_creator_id           (creator_id)
#  index_permissions_on_project_id           (project_id)
#  index_permissions_on_updater_id           (updater_id)
#  index_permissions_on_user_id              (user_id)
#  permissions_project_allow_anonymous_uidx  (project_id,allow_anonymous) UNIQUE WHERE (allow_anonymous IS TRUE)
#  permissions_project_allow_logged_in_uidx  (project_id,allow_logged_in) UNIQUE WHERE (allow_logged_in IS TRUE)
#  permissions_project_user_uidx             (project_id,user_id) UNIQUE WHERE (user_id IS NOT NULL)
#
# Foreign Keys
#
#  permissions_creator_id_fk  (creator_id => users.id)
#  permissions_project_id_fk  (project_id => projects.id)
#  permissions_updater_id_fk  (updater_id => users.id)
#  permissions_user_id_fk     (user_id => users.id)
#
describe Permission, type: :model do
  subject { FactoryBot.build(:read_permission, project: FactoryBot.create(:project)) }

  it do
    is_expected.to belong_to(:creator).class_name('User').with_foreign_key(:creator_id).inverse_of(:created_permissions)
  end
  it do
    is_expected.to \
      belong_to(:updater).class_name('User').with_foreign_key(:updater_id).inverse_of(:updated_permissions).optional
  end
  it { is_expected.to belong_to(:project).inverse_of(:permissions) }
  it { is_expected.to belong_to(:user).inverse_of(:permissions).without_validating_presence }

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
    let(:user) { FactoryBot.create(:user) }
    let(:project) { FactoryBot.create(:project, creator: user) }

    context 'enforces exactly one permission setting per project' do
      context 'fails with' do
        it 'no settings' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: nil, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end

        it 'allow_anonymous and allow_logged_in' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: nil, allow_logged_in: true, allow_anonymous: true)
          expect(permission).not_to be_valid
        end

        it 'user and allow_anonymous' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: true)
          expect(permission).not_to be_valid
        end

        it 'user and allow_logged_in' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: user, allow_logged_in: true, allow_anonymous: false)
          expect(permission).not_to be_valid
        end

        it 'user and allow_anonymous and allow_logged_in' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: user, allow_logged_in: true, allow_anonymous: true)
          expect(permission).not_to be_valid
        end
        it 'user at invalid level' do
          permission = FactoryBot.build(:permission, level: 'something_wrong', creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end
        it 'user at nil level' do
          permission = FactoryBot.build(:permission, level: nil, creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).not_to be_valid
        end
      end
      context 'succeeds with' do
        it 'user at reader level' do
          permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
        it 'user at writer level' do
          permission = FactoryBot.build(:permission, level: 'writer', creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
        it 'user at owner level' do
          permission = FactoryBot.build(:permission, level: 'owner', creator: user,
                                                     user: user, allow_logged_in: false, allow_anonymous: false)
          expect(permission).to be_valid
        end
      end
    end

    context 'enforces levels for logged_in' do
      it 'fails for invalid level value' do
        permission = FactoryBot.build(:permission, level: 'something_wrong', creator: user,
                                                   user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
      it 'fails for nil level' do
        permission = FactoryBot.build(:permission, level: nil, creator: user,
                                                   user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
      it 'succeeds for reader level' do
        permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                   user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).to be_valid
      end
      it 'succeeds for writer level' do
        permission = FactoryBot.build(:permission, level: 'writer', creator: user,
                                                   user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).to be_valid
      end
      it 'fails for owner level' do
        permission = FactoryBot.build(:permission, level: 'owner', creator: user,
                                                   user: nil, allow_logged_in: true, allow_anonymous: false)
        expect(permission).not_to be_valid
      end
    end

    context 'enforces levels for anonymous' do
      it 'fails for invalid level value' do
        permission = FactoryBot.build(:permission, level: 'something_wrong', creator: user,
                                                   user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'fails for nil level' do
        permission = FactoryBot.build(:permission, level: nil, creator: user,
                                                   user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'succeeds for reader level' do
        permission = FactoryBot.build(:permission, level: 'reader', creator: user,
                                                   user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).to be_valid
      end
      it 'fails for writer level' do
        permission = FactoryBot.build(:permission, level: 'writer', creator: user,
                                                   user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
      it 'fails for owner level' do
        permission = FactoryBot.build(:permission, level: 'owner', creator: user,
                                                   user: nil, allow_logged_in: false, allow_anonymous: true)
        expect(permission).not_to be_valid
      end
    end
  end
end
