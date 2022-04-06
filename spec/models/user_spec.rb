# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :integer          not null, primary key
#  authentication_token   :string
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           not null
#  encrypted_password     :string           not null
#  failed_attempts        :integer          default(0)
#  image_content_type     :string
#  image_file_name        :string
#  image_file_size        :integer
#  image_updated_at       :datetime
#  invitation_token       :string
#  last_seen_at           :datetime
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  locked_at              :datetime
#  preferences            :text
#  rails_tz               :string(255)
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  roles_mask             :integer
#  sign_in_count          :integer          default(0)
#  tzinfo_tz              :string(255)
#  unconfirmed_email      :string
#  unlock_token           :string
#  user_name              :string           not null
#  created_at             :datetime
#  updated_at             :datetime
#
# Indexes
#
#  index_users_on_authentication_token  (authentication_token) UNIQUE
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  users_user_name_unique               (user_name) UNIQUE
#
describe User, type: :model do
  it 'errors on invalid timezone' do
    expect {
      create(:user, tzinfo_tz: 'blah')
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Tzinfo tz is not a recognized timezone ('blah')")
  end

  it 'is valid for a valid timezone' do
    expect(create(:user, tzinfo_tz: 'Australia - Brisbane')).to be_valid
  end

  it 'is valid for a nil tzinfo' do
    expect(create(:user, tzinfo_tz: nil)).to be_valid
  end

  # see https://github.com/QutBioacoustics/baw-server/issues/270
  # We store friendly values
  it 'does not allow bad tz_info' do
    user = create(:user)

    user.tzinfo_tz = 'Australia/fsdjljfssl'
    user.rails_tz = 'Sydney'

    expect {
      user.save!
    }.to raise_exception(ActiveRecord::RecordInvalid, /Validation failed: Tzinfo tz is not a recognized timezone/)
  end

  it 'includes TimeZoneAttribute' do
    expect(User.new).to be_a_kind_of(TimeZoneAttribute)
  end

  it { is_expected.to have_many(:created_regions) }
  it { is_expected.to have_many(:updated_regions) }
  it { is_expected.to have_many(:deleted_regions) }
  it { is_expected.to have_many(:created_harvests) }
  it { is_expected.to have_many(:updated_harvests) }
  it { is_expected.to have_one(:statistics) }

  context 'when using the recently seen scope' do
    KEYS = [:last_seen_at, :current_sign_in_at, :last_sign_in_at].freeze
    subject(:user) { create(:user) }

    before do
      old = 2.months.ago

      KEYS.each { |key| user[key] = old }
      user.save!
    end

    it 'does not show non-recent users' do
      expect(User.recently_seen(1.month.ago).to_a).not_to include(user)
    end

    KEYS.each { |key|
      it "will show if #{key} is recent" do
        user[key] = 1.day.ago
        user.save!
        expect(User.recently_seen(1.month.ago).to_a).to include(user)
      end
    }
  end

  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image)
  #                 .allowing('image/gif', 'image/jpeg', 'image/jpg','image/png', 'image/x-png', 'image/pjpeg')
  #                 .rejecting('text/xml', 'image_maybe/abc', 'some_image/png','text/plain') }
end
