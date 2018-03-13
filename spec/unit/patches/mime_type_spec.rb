require 'rails_helper'


describe 'mime type extension patch' do

  let(:mime_types) {
    [
        ["audio/x-wav", 'wav'],
        ["audio/wav", 'wav'],
        ["audio/vnd.wave", 'wav'],
        ["audio/mp3", 'mp3'],
        ["audio/mpeg", 'mp3'],
        ["video/x-ms-asf", 'asf'],
        ["audio/x-ms-wma", 'asf'],
        ["audio/x-wv", 'wv'],
        ["audio/flac", 'flac'],
    ]
  }

  it 'ensures that we can get an extension' do
    mime_types.each do |test_case|
      media_type = test_case[0]
      expected_extension = test_case[1]

      actual_extension = Mime::Type.file_extension_of(media_type)

      expect(actual_extension).to eq(expected_extension)
    end
  end

end

