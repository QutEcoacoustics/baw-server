require 'spec_helper'

describe Script do
  #pending "add some examples to (or delete) #{__FILE__}"

  it { should validate_attachment_content_type(:settings_file).
                  allowing('text/plain').
                  rejecting('text/plain1', 'image/gif', 'image/jpeg', 'image/png', 'text/xml', 'image/abc', 'some_image/png', 'text2/plain') }

end
