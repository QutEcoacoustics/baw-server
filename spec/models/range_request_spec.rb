# frozen_string_literal: true

require 'rails_helper'

describe RangeRequest, type: :model do

  let(:range_request) { RangeRequest.new }

  let(:audio_file_mono) { Fixtures.audio_file_mono }
  let(:audio_file_mono_media_type) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_size_bytes) { 822_281 }
  let(:audio_file_mono_modified_time) { File.mtime(audio_file_mono) }
  let(:audio_file_mono_etag) {
    etag_string = audio_file_mono.to_s + '|' + audio_file_mono_modified_time.getutc.to_s + '|' + audio_file_mono_size_bytes.to_s
    Digest::SHA256.hexdigest etag_string
  }

  let(:audio_file_mono_long) { Fixtures.audio_file_mono_long }
  let(:audio_file_mono_media_type_long) { Mime::Type.lookup('audio/ogg') }
  let(:audio_file_mono_size_bytes_long) { 1_317_526 }
  let(:audio_file_mono_modified_time_long) { File.mtime(audio_file_mono_long) }
  let(:audio_file_mono_etag_long) {
    etag_string = audio_file_mono_long.to_s + '|' + audio_file_mono_modified_time_long.getutc.to_s + '|' + audio_file_mono_size_bytes_long.to_s
    Digest::SHA256.hexdigest etag_string
  }

  let(:range_options) {
    {
      start_offset: 11,
      end_offset: 34,
      recorded_date: Time.zone.now,
      site_name: 'site_name',
      site_id: 42,
      ext: audio_file_mono_media_type.to_sym.to_s,
      file_path: audio_file_mono,
      media_type: audio_file_mono_media_type.to_s
    }
  }

  let(:range_options_long) {
    {
      start_offset: 11,
      end_offset: 151,
      recorded_date: Time.zone.now,
      site_name: 'site_name',
      site_id: 42,
      ext: audio_file_mono_media_type_long.to_sym.to_s,
      file_path: audio_file_mono_long,
      media_type: audio_file_mono_media_type_long.to_s
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

    buffer = String.new
    StringIO.open(buffer, 'w') do |string_io|
      range_request.write_content_to_output(info, string_io)
    end

    expected_buffer = String.new
    open info[:file_path], 'r' do |f|
      f.seek(9, IO::SEEK_SET)
      expected_buffer = f.read(21 - 9 + 1)
    end

    expect(buffer).to eq(expected_buffer)
  end

  it 'should write the expected multiple range parts of the file' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=9-21,60-70'
    info = range_request.build_response(range_options, mock_request)

    buffer = String.new
    StringIO.open(buffer, 'w') do |string_io|
      range_request.write_content_to_output(info, string_io)
    end

    expected_buffer = []
    open info[:file_path], 'r' do |f|
      f.seek(9, IO::SEEK_SET)
      expected_buffer.push(f.read((21 - 9 + 1)))

      f.seek(60, IO::SEEK_SET)
      expected_buffer.push(f.read((70 - 60 + 1)))
    end

    expect(buffer).to include(expected_buffer[0])
    expect(buffer).to include(expected_buffer[1])
  end

  it 'should succeed with: [] without: [single range, multiple ranges, modified, match, match range]' do
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with: [single range] without: [multiple ranges,modified, match, match range]' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=0-10'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with: [multiple ranges] without: [single range, modified, match, match range]' do
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=,-,-500,0-10,50-,'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_truthy

    expect(info[:range_start_bytes][0]).to eq(0)
    expect(info[:range_end_bytes][0]).to eq(range_request.max_range_size - 1)

    expect(info[:range_start_bytes][1]).to eq(0)
    expect(info[:range_end_bytes][1]).to eq(range_request.max_range_size - 1)

    # last 654321 bytes (or last max_range_size, which ever is smaller)
    expect(info[:range_start_bytes][2]).to eq(audio_file_mono_size_bytes - 500)
    expect(info[:range_end_bytes][2]).to eq(audio_file_mono_size_bytes - 1)

    expect(info[:range_start_bytes][3]).to eq(0)
    expect(info[:range_end_bytes][3]).to eq(10)

    expect(info[:range_start_bytes][4]).to eq(50)
    expect(info[:range_end_bytes][4]).to eq(range_request.max_range_size + 50 - 1)
  end

  context 'special open end range case' do
    # this test case comes from a real-world production bug: https://github.com/QutBioacoustics/baw-server/issues/318
    # the second part of a large range request triggers a negative content length and the last part of the content
    # range header to be less than the first part.

    # before bug fix:
    # file_size:                                  822281
    # request:                      "Range: bytes 512001-"
    # info[:range_start]:                         512001
    # info[:range_end]:                           310279       <-- problem, end less than start!
    # info[:response_headers]['Content-Length']: -201721       <-- problem, negative range!
    it 'should succeed with: [single range] special test case, open range greater than max range size' do
      mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=512001-'
      info = range_request.build_response(range_options, mock_request)
      expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
      expect(info[:response_is_range]).to be_truthy
      expect(info[:is_multipart]).to be_falsey

      expect(info[:range_start_bytes][0]).to eq(512_001)
      expect(info[:range_end_bytes][0]).to eq(audio_file_mono_size_bytes - 1)

      expect(info[:response_headers]['Content-Length']).to eq(310_280.to_s)
    end

    it 'should succeed with: [single range] special test case, open range greater than max range size, larger file' do
      mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=512001-'

      # ensure xxx- range still honors max_range_size
      # using the LONG file here!
      info = range_request.build_response(range_options_long, mock_request)
      expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
      expect(info[:response_is_range]).to be_truthy
      expect(info[:is_multipart]).to be_falsey

      expect(info[:range_start_bytes][0]).to eq(512_001)
      # > "abcdefghij"[3..(3+5-1)]
      # => "defgh"
      expect(info[:range_end_bytes][0]).to eq(512_001 + range_request.max_range_size - 1)

      expect(info[:response_headers]['Content-Length']).to eq(range_request.max_range_size.to_s)
    end

    it 'should succeed with: [single range] special test case, last bytes greater than max range offset' do
      mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=-500'
      info = range_request.build_response(range_options, mock_request)
      expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
      expect(info[:response_is_range]).to be_truthy
      expect(info[:is_multipart]).to be_falsey

      expect(info[:range_start_bytes][0]).to eq(audio_file_mono_size_bytes - 500) # 821781
      expect(info[:range_end_bytes][0]).to eq(audio_file_mono_size_bytes - 1)

      expect(info[:response_headers]['Content-Length']).to eq(500.to_s)
    end

    it 'should succeed with: [single range] special test case, last bytes range greater than max range size' do
      mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=-800000'
      info = range_request.build_response(range_options, mock_request)
      expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
      expect(info[:response_is_range]).to be_truthy
      expect(info[:is_multipart]).to be_falsey

      expect(info[:range_start_bytes][0]).to eq(audio_file_mono_size_bytes - range_request.max_range_size)
      expect(info[:range_end_bytes][0]).to eq(audio_file_mono_size_bytes - 1)

      expect(info[:response_headers]['Content-Length']).to eq(range_request.max_range_size.to_s)
    end

    it 'should succeed with: [single range] special test case, entire file' do
      mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=0-822280'
      range_request = RangeRequest.new(1_000_000)
      info = range_request.build_response(range_options, mock_request)
      expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
      expect(info[:response_is_range]).to be_truthy
      expect(info[:is_multipart]).to be_falsey

      expect(info[:range_start_bytes][0]).to eq(0)
      expect(info[:range_end_bytes][0]).to eq(audio_file_mono_size_bytes - 1)

      expect(info[:response_headers]['Content-Length']).to eq(audio_file_mono_size_bytes.to_s)
    end
  end

  it 'should succeed with if-modified-since earlier than file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: -100).httpdate
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with if-modified-since later than file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: 100).httpdate
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with if-modified-since matching file modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = audio_file_mono_modified_time.httpdate
    info = range_request.build_response(range_options, mock_request)

    fmt = info[:file_modified_time]
    tzp = Time.zone.parse(audio_file_mono_modified_time.httpdate)
    file_mt = File.mtime(audio_file_mono)

    info_msg = {
      httpdate: audio_file_mono_modified_time.httpdate,
      file_mtime_utc: file_mt.getutc,
      time_zone_parse: tzp,
      file_modified_time: fmt.getutc,
      file_modified_time_f: fmt.getutc.to_f,
      time_zone_parse_utc: tzp.getutc,
      time_zone_parse_utc_f: tzp.getutc.to_f,
      compare: fmt.getutc <= tzp.getutc,
      expected: RangeRequest::HTTP_CODE_NOT_MODIFIED,
      actual: info[:response_code]
    }

    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED), info_msg.to_json
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with if-modified-since invalid time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MODIFIED_SINCE] = 'blah blah blah'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with a single range not modified' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_RANGE] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range when etag does not match' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_RANGE] = 'not the same'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_OK)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with a If-Unmodified-Since after file last modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_UNMODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: 100).httpdate
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a If-Unmodified-Since before file last modified time' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_UNMODIFIED_SINCE] = audio_file_mono_modified_time.advance(seconds: -100).httpdate
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PRECONDITION_FAILED)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
  end

  it 'should succeed with a single range and matching if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range and * if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = '*'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

  it 'should succeed with a single range and non-matching if-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_MATCH] = 'blah blah blah'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PRECONDITION_FAILED)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and matching if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = audio_file_mono_etag
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and * if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = '*'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_NOT_MODIFIED)
    expect(info[:response_is_range]).to be_falsey
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes].size).to eq(0)
  end

  it 'should succeed with a single range and non-matching if-none-match header' do
    mock_request.headers[RangeRequest::HTTP_HEADER_IF_NONE_MATCH] = 'blah blah blah'
    mock_request.headers[RangeRequest::HTTP_HEADER_RANGE] = 'bytes=50-100'
    info = range_request.build_response(range_options, mock_request)
    expect(info[:response_code]).to eq(RangeRequest::HTTP_CODE_PARTIAL_CONTENT)
    expect(info[:response_is_range]).to be_truthy
    expect(info[:is_multipart]).to be_falsey
    expect(info[:range_start_bytes][0]).to eq(50)
    expect(info[:range_end_bytes][0]).to eq(100)
  end

end
