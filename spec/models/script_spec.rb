require 'spec_helper'

describe Script do
  #pending "add some examples to (or delete) #{__FILE__}"


  it { should validate_attachment_content_type(:settings_file).
                  allowing('text/plain').
                  rejecting( 'image/gif', 'image/jpeg', 'text/xml', 'image/abc', 'some_image/png') }

end
