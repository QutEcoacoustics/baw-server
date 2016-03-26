require 'rails_helper'

describe User, :type => :model do


  it 'should error on invalid timezone' do
    expect {
      FactoryGirl.create(:user, tzinfo_tz: 'blah')
    }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Tzinfo tz is not a recognised timezone ('blah')")
  end

  it 'should be valid for a valid timezone' do
    expect(FactoryGirl.create(:user, tzinfo_tz: 'Australia - Brisbane')).to be_valid
  end

  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:image)
  #                 .allowing('image/gif', 'image/jpeg', 'image/jpg','image/png', 'image/x-png', 'image/pjpeg')
  #                 .rejecting('text/xml', 'image_maybe/abc', 'some_image/png','text/plain') }
end
