require 'spec_helper'

describe Script, :type => :model do
  #pending "add some examples to (or delete) #{__FILE__}"

  # this should pass, but the paperclip implementation of validate_attachment_content_type is buggy.
  # it { should validate_attachment_content_type(:settings_file).
  #                 allowing('text/plain').
  #                 rejecting('text/plain1', 'image/gif', 'image/jpeg', 'image/png', 'text/xml', 'image/abc', 'some_image/png', 'text2/plain') }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
end
