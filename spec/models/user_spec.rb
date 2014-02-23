require 'spec_helper'

describe User do
  #pending "add some examples to (or delete) #{__FILE__}"

  it { should validate_attachment_content_type(:image).
                  allowing('image/gif', 'image/jpeg', 'image/jpg','image/png').
                  rejecting('text/xml', 'image_maybe/abc', 'some_image/png') }
end
