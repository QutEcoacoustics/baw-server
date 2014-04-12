require 'spec_helper'

describe RangeRequest do

  let(:range_request) { RangeRequest.new }

  let(:audio_file_mono) { File.expand_path(File.join(File.dirname(__FILE__), '..', 'media_tools', 'test-audio-mono.ogg')) }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_size_bytes) { 822281 }
  let(:audio_file_mono_modified_time) { File.mtime(audio_file_mono) }
  let(:audio_file_mono_etag) {
    etag_string = audio_file_mono.to_s + '|' + audio_file_mono_modified_time.getutc.to_s + '|' + audio_file_mono_size_bytes.to_s
    Digest::SHA256.hexdigest etag_string
 }


  let(:range_options) {
    {
        start_offset: 11,
        end_offset: 34,
        recorded_date: Time.zone.now,
        site_name: 'site_name',
        ext: audio_file_mono_media_type.to_sym.to_s,
        file_path: audio_file_mono,
        media_type: audio_file_mono_media_type.to_s
    }
  }

  let(:mock_request) {
    container = OpenStruct.new
    container.headers = {}
    container
  }

  # http://stackoverflow.com/questions/17820907/comparing-bytes-in-ruby
  # This is an encoding issue. You are comparing a string with binary encoding (your JPEG blob) with a UTF-8 encoded string ("\xFF"):
  #
  #     foo = "\xFF".force_encoding("BINARY") # like your blob
  #     bar = "\xFF"
  #     p foo         # => "\xFF"
  #     p bar         # => "\xFF"
  #     p foo == bar  # => false
  # There are several ways to create a binary encoded string:
  #
  #                                                       str = "\xFF\xD8".force_encoding("BINARY")  # => "\xFF\xD8"
  # str.encoding                               # => #<Encoding:ASCII-8BIT>
  #
  # str = 0xFF.chr + 0xD8.chr                  # => "\xFF\xD8"
  # str.encoding                               # => #<Encoding:ASCII-8BIT>
  #
  # str = ["FFD8"].pack("H*")                  # => "\xFF\xD8"
  # str.encoding                               # => #<Encoding:ASCII-8BIT>
  # All of the above can be compared with your blob.

  it 'should write the expected single range part of the file' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=9-21'
    info = range_request.build_response(range_options, mock_request)

    buffer = ''
    StringIO.open(buffer, 'w') { |string_io|
      range_request.write_content_to_output(info, string_io)
    }

    expected_buffer = ''
    open info[:file_path], 'r' do |f|
      f.seek(9, IO::SEEK_SET)
      expected_buffer = f.read (21-9 + 1)
    end

    expect(buffer).to eq(expected_buffer)
  end

  it 'should write the expected multiple range parts of the file' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=9-21,60-70'
    info = range_request.build_response(range_options, mock_request)

    buffer = ''
    StringIO.open(buffer, 'w') { |string_io|
      range_request.write_content_to_output(info, string_io)
    }

    expected_buffer = []
    open info[:file_path], 'r' do |f|
      f.seek(9, IO::SEEK_SET)
      expected_buffer.push(f.read (21-9 + 1))

      f.seek(60, IO::SEEK_SET)
      expected_buffer.push(f.read (70-60 + 1))
    end

    expect(buffer).to include(expected_buffer[0])
    expect(buffer).to include(expected_buffer[1])
  end

  it 'should succeed with: [] without: [single range, multiple ranges, modified, match, match range]' do
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with: [single range] without: [multiple ranges,modified, match, match range]' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=0-10'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with: [multiple ranges] without: [single range, modified, match, match range]' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=,-,-500,0-10,50-,'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_true

    expect(info[:range_start_bytes][0]).to eq(0)
    expect(info[:range_end_bytes][0]).to eq(range_request.max_range_size)

    expect(info[:range_start_bytes][1]).to eq(0)
    expect(info[:range_end_bytes][1]).to eq(range_request.max_range_size)

    # last 654321 bytes (or last max_range_size, which ever is smaller)
    expect(info[:range_start_bytes][2]).to eq(audio_file_mono_size_bytes - 500 - 1)
    expect(info[:range_end_bytes][2]).to eq(audio_file_mono_size_bytes - 1)

    expect(info[:range_start_bytes][3]).to eq(0)
    expect(info[:range_end_bytes][3]).to eq(10)

    expect(info[:range_start_bytes][4]).to eq(50)
    expect(info[:range_end_bytes][4]).to eq(range_request.max_range_size + 50)

    expect(info[:range_start_bytes][1]).to eq(0)
    expect(info[:range_end_bytes][1]).to eq(range_request.max_range_size)
  end

  it 'should succeed with if-modified-since earlier than file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: -100).httpdate
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with if-modified-since later than file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: 100).httpdate
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with if-modified-since matching file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.httpdate
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED), "Header modified: #{audio_file_mono_modified_time}, current: #{File.mtime(audio_file_mono)}"
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with if-modified-since invalid time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = 'blah blah blah'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with a single range not modified' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_RANGE] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range when etag does not match' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_RANGE] = 'not the same'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with a If-Unmodified-Since after file last modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_UNMODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: 100).httpdate
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a If-Unmodified-Since before file last modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_UNMODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: -100).httpdate
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PRECONDITION_FAILED)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
  end

  it 'should succeed with a single range and matching if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range and * if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = '*'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range and non-matching if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = 'blah blah blah'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PRECONDITION_FAILED)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and matching if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and * if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = '*'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_false
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and non-matching if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = 'blah blah blah'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_true
    expect(info[:is_multipart]).to be_false
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

end