# frozen_string_literal: true

require 'rails_helper'

describe User, type: :model do
  it 'should error on invalid timezone' do
    expect {
      FactoryBot.create(:user, tzinfo_tz: 'blah')
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Tzinfo tz is not a recognised timezone ('blah')")
  end

  it 'should be valid for a valid timezone' do
    expect(FactoryBot.create(:user, tzinfo_tz: 'Australia - Brisbane')).to be_valid
  end

  it 'should be valid for a nil tzinfo' do
    expect(FactoryBot.create(:user, tzinfo_tz: nil)).to be_valid
  end

  # see https://github.com/QutBioacoustics/baw-server/issues/270
  # We store friendly values
  it 'should not allow bad tz_info' do
    user = FactoryBot.create(:user)

    user.tzinfo_tz = 'Australia/Sydney'
    user.rails_tz = 'Sydney'

    expect {
      user.save!
    }.to raise_exception(ActiveRecord::RecordInvalid, /Validation failed: Tzinfo tz is not a recognised timezone/)
  end

  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image)
  #                 .allowing('image/gif', 'image/jpeg', 'image/jpg','image/png', 'image/x-png', 'image/pjpeg')
  #                 .rejecting('text/xml', 'image_maybe/abc', 'some_image/png','text/plain') }
end
