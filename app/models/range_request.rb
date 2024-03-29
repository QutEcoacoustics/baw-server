# frozen_string_literal: true

#
# A Range Request processor, modified and ported to Ruby by Mark Cottman-Fields.
#
# Based on an abstract HTTP Handler that provides resumable file downloads in ASP.Net.
#
# Created by:
#     Scott Mitchell
#     mitchell@4guysfromrolla.com
#     http://www.4guysfromrolla.com/ScottMitchell.shtml
#
# This class is a fairly close port of Alexander Schaaf's ZIPHandler HTTP Handler, which was found online at:
#
#     Tracking and Resuming Large File Downloads in ASP.NET
#     http://www.devx.com/dotnet/Article/22533/1954
#
# A similar version of this code is included in the download for the September 2006 issue of MSDN Magazine:
# http://download.microsoft.com/download/f/2/7/f279e71e-efb0-4155-873d-5554a0608523/MSDNMag2006_09.exe
#
# Alexander's code is in Visual Basic and was written for ASP.NET version 1.x. Scott ported the code to C#,
# refactored portions of the code, and made use of functionality and features introduced in .NET 2.0 and 3.5.
#

class RangeRequest
  module Constants
    MULTIPART_BOUNDARY = '<q1w2e3r4t5y6u7i8o9p0>'
    MULTIPART_CONTENT_TYPE = "multipart/byteranges boundary=#{MULTIPART_BOUNDARY}".freeze
    DEFAULT_CONTENT_TYPE = 'application/octet-stream'
    MULTIPART_HEADER_LENGTH = 49
    MULTIPART_DASH_LINE_BREAK_LENGTH = 8
    CONVERT_INDEX_TO_LENGTH = 1
    CONVERT_LENGTH_TO_INDEX = -1
    REQUIRED_PARAMETERS = [
      :start_offset, :end_offset, :recorded_date, :site_id, :site_name, :ext,
      :file_path,
      :file_size,
      :media_type
    ].freeze

    HTTP_HEADER_ACCEPT_RANGES = 'Accept-Ranges'
    HTTP_HEADER_ACCEPT_RANGES_BYTES = 'bytes'
    HTTP_HEADER_ACCEPT_RANGES_BYTES_EQUAL = 'bytes='
    HTTP_HEADER_ACCEPT_RANGES_NONE = 'none'
    HTTP_HEADER_CONTENT_TYPE = 'Content-Type'
    HTTP_HEADER_CONTENT_RANGE = 'Content-Range'
    HTTP_HEADER_CONTENT_LENGTH = 'Content-Length'
    HTTP_HEADER_CONTENT_DISPOSITION = 'Content-Disposition'
    HTTP_HEADER_ENTITY_TAG = 'ETag'
    HTTP_HEADER_LAST_MODIFIED = 'Last-Modified'
    HTTP_HEADER_RANGE = 'Range'
    HTTP_HEADER_IF_RANGE = 'If-Range'
    HTTP_HEADER_IF_MATCH = 'If-Match'
    HTTP_HEADER_IF_NONE_MATCH = 'If-None-Match'
    HTTP_HEADER_IF_MODIFIED_SINCE = 'If-Modified-Since'
    HTTP_HEADER_IF_UNMODIFIED_SINCE = 'If-Unmodified-Since'
    HTTP_HEADER_UNLESS_MODIFIED_SINCE = 'Unless-Modified-Since'

    HTTP_METHOD_GET = 'GET'
    HTTP_METHOD_HEAD = 'HEAD'

    HTTP_CODE_PARTIAL_CONTENT = 206
    HTTP_CODE_PRECONDITION_FAILED = 412
    HTTP_CODE_RANGE_NOT_SATISFIABLE = 416
    HTTP_CODE_NOT_MODIFIED = 304
    HTTP_CODE_OK = 200
  end
  include Constants

  attr_reader :max_range_size, :write_buffer_size

  # @param [int] max_range_size Maximum range length in bytes
  # @param [int] write_buffer_size Buffer write size in bytes
  def initialize(max_range_size = 512_000, write_buffer_size = 10_240)
    @max_range_size = max_range_size
    @write_buffer_size = write_buffer_size
  end

  # @param [Hash] options
  def build_response(options, rails_request)
    check_options(options, REQUIRED_PARAMETERS)

    info = response_info(options, rails_request)

    info.deep_merge!(response_range(info)) unless info[:requested_range].blank?

    # auth is performed elsewhere
    # only HTTP get will access this
    # the requested file is checked elsewhere (size and whether it exists)

    info.deep_merge!(response_conditions_modified(info))
    info.deep_merge!(response_conditions_unmodified(info))
    info.deep_merge!(response_conditions_etag_match(info))
    info.deep_merge!(response_conditions_etag_no_match(info))
    info.deep_merge!(response_conditions_range(info))

    unless info[:response_is_range]
      info[:range_start_bytes] = []
      info[:range_end_bytes] = []
    end

    unless info[:stop_processing_request_headers]
      info.deep_merge!(response_headers_common(info))
      info.deep_merge!(response_headers_entire(info))
      info.deep_merge!(response_headers_single_part(info))
      info.deep_merge!(response_headers_multi_part(info))
    end

    info[:response_headers] = modify_headers(info)

    info
  end

  # @param [Hash] info
  # @param [IO] output_io
  def write_content_to_output(in_buffer, info, output_io)
    StringIO.open(in_buffer, 'rb') { |file_io| # rb = readonly binary
      write_io_content_to_output(file_io, info, output_io)
    }
  end

  def write_file_content_to_output(path, info, output_io)
    File.open(path, 'rb') { |file_io| # rb = readonly binary
      write_io_content_to_output(file_io, info, output_io)
    }
  end

  def write_io_content_to_output(input_io, info, output_io)
    info[:range_start_bytes].size.times do |index|
      range_start = info[:range_start_bytes][index].to_i
      range_end = info[:range_end_bytes][index].to_i

      input_io.seek(range_start, IO::SEEK_SET)

      remaining = range_end - range_start + CONVERT_INDEX_TO_LENGTH

      if info[:is_multipart]
        output_io.write("--#{MULTIPART_BOUNDARY}\r\n")
        output_io.write("#{HTTP_HEADER_CONTENT_TYPE}: #{info[:file_media_type]}\r\n")
        output_io.write("#{HTTP_HEADER_CONTENT_RANGE}: #{HTTP_HEADER_ACCEPT_RANGES_BYTES} #{range_start}-#{range_end}/#{info[:file_size]}\r\n")
      end

      while remaining.positive?
        # check if client is connected

        # calculate check size
        chunk_size = @write_buffer_size < remaining ? @write_buffer_size : remaining
        data = input_io.read(chunk_size)
        output_io.write(data)

        remaining -= chunk_size
        output_io.flush
      end
    end

    # io is closed by ruby block
  end

  private

  def modify_headers(info)
    modified_headers = {}

    info[:response_headers].each do |key, value|
      # make sure headers are in the correct format, and the values are all strings
      modified_headers[key.to_s.dasherize.split('-').each { |v| v[0] = v[0].chr.upcase }.join('-')] = value.to_s
    end

    modified_headers
  end

  def check_options(options, sym_array)
    msg = 'RangeRequest - Required parameter missing:'
    # possibility of a buffer in here, can't print hash itself
    provided = "Provided parameters: #{options.keys}"
    sym_array.each do |sym|
      raise ArgumentError, "#{msg} #{sym}. #{provided}" unless options.include?(sym) && !options[sym].blank?
    end
  end

  def file_entity_tag(info)
    # create the ETag from full file path and last modified date of file
    etag_string = "#{info[:file_path]}|#{info[:file_modified_time].getutc}|#{info[:file_size]}"
    Digest::SHA256.hexdigest etag_string
  end

  def response_headers_multi_part(info)
    return {} if !info[:is_multipart] || !info[:is_range]

    return_value = {}

    # calculate content length for each range
    content_length = 0
    info[:range_start_bytes].size.times do |index|
      range_start = info[:range_start_bytes][index]
      range_end = info[:range_end_bytes][index]

      content_length += (range_end - range_start) + CONVERT_INDEX_TO_LENGTH

      content_length += (
      MULTIPART_BOUNDARY.size +
          info[:file_media_type].size +
          range_start.to_s.size +
          range_end.to_s.size +
          info[:file_size].to_s.size +
          MULTIPART_HEADER_LENGTH
    )
    end

    content_length += MULTIPART_BOUNDARY.size + MULTIPART_DASH_LINE_BREAK_LENGTH

    return_value[:response_code] = HTTP_CODE_PARTIAL_CONTENT

    return_value[:response_headers] = {}
    return_value[:response_headers][HTTP_HEADER_CONTENT_LENGTH] = content_length
    return_value[:response_headers][HTTP_HEADER_CONTENT_TYPE] = MULTIPART_CONTENT_TYPE

    return_value
  end

  def response_headers_single_part(info)
    return {} if info[:is_multipart] || !info[:is_range]

    return_value = {}

    range_start = info[:range_start_bytes][0]
    range_end = info[:range_end_bytes][0]
    file_size = info[:file_size]

    content_length = (range_end - range_start) + CONVERT_INDEX_TO_LENGTH

    unsatisfiable = range_start >= (file_size + CONVERT_LENGTH_TO_INDEX)
    return_value[:response_code] = unsatisfiable ? HTTP_CODE_RANGE_NOT_SATISFIABLE : HTTP_CODE_PARTIAL_CONTENT

    return_value[:response_headers] = {}
    if unsatisfiable
      # https://datatracker.ietf.org/doc/html/rfc7233#section-4.2
      "#{HTTP_HEADER_ACCEPT_RANGES_BYTES} */#{file_size}"
    else
      "#{HTTP_HEADER_ACCEPT_RANGES_BYTES} #{range_start}-#{range_end}/#{file_size}"
    end => range_header

    return_value[:response_headers][HTTP_HEADER_CONTENT_RANGE] = range_header
    return_value[:response_headers][HTTP_HEADER_CONTENT_LENGTH] = content_length
    return_value[:response_headers][HTTP_HEADER_CONTENT_TYPE] = info[:file_media_type]

    return_value
  end

  def response_headers_entire(info)
    return {} if info[:is_range]

    return_value = {}

    return_value[:response_code] = HTTP_CODE_OK

    return_value[:response_headers] = {}
    return_value[:response_headers][HTTP_HEADER_CONTENT_LENGTH] = info[:file_size]
    return_value[:response_headers][HTTP_HEADER_CONTENT_TYPE] = info[:file_media_type]

    return_value
  end

  def response_headers_common(info)
    return_value = {}

    return_value[:response_headers] = {}
    return_value[:response_headers][HTTP_HEADER_LAST_MODIFIED] = info[:file_modified_time].httpdate
    return_value[:response_headers][HTTP_HEADER_ENTITY_TAG] = "\"#{info[:file_entity_tag]}\""
    return_value[:response_headers][HTTP_HEADER_ACCEPT_RANGES] = HTTP_HEADER_ACCEPT_RANGES_BYTES
    return_value[:response_headers][HTTP_HEADER_CONTENT_DISPOSITION] =
      "#{info[:response_disposition_type]}; filename=\"#{info[:response_suggested_file_name]}\""

    return_value
  end

  def response_info(options, rails_request)
    file_path = File.expand_path(options[:file_path])
    media_type = options[:media_type]

    range_header = rails_request.headers[HTTP_HEADER_RANGE]

    audio_recording = {
      id: options[:recording_id],
      recorded_date: options[:recorded_date],
      site: {
        id: options[:site_id],
        name: options[:site_name]
      }
    }
    response_extra_info = "#{options[:channel]}_#{options[:sample_rate]}"

    suggested_file_name = options[:suggested_file_name] || NameyWamey.create_audio_recording_name(
      audio_recording,
      options[:start_offset], options[:end_offset],
      response_extra_info, options[:ext]
    )
    disposition_type = options[:disposition_type] || :inline
    unless [:inline, :attachment].include?(disposition_type)
      raise ArgumentError, "Unknown content disposition type #{disposition_type}"
    end

    file_modified_time = File.exist?(file_path) ? File.mtime(file_path).getutc : Time.now
    file_size = options[:file_size]

    # convert request headers to a hash
    request_headers_hash = {}
    rails_request.headers.each do |key, value|
      request_headers_hash[key] = value
    end

    info = {
      # Indicates if the HTTP request is for multiple ranges.
      is_multipart: false,

      # Indicates if the HTTP request is for one or more ranges.
      is_range: false,

      # The start byte(s) for the requested range(s).
      range_start_bytes: [],

      # the smallest possible value for range_start_bytes
      range_start_bytes_min: 0,

      # The end byte(s) for the requested range(s).
      range_end_bytes: [],

      # the largest possible value for range_end_bytes
      range_end_bytes_max: file_size + CONVERT_LENGTH_TO_INDEX,

      range_length_max: @max_range_size,
      write_buffer_size: @write_buffer_size,

      requested_range: range_header,

      # to ensure a new hash is used
      # http://thingsaaronmade.com/blog/ruby-shallow-copy-surprise.html
      request_headers: {}.merge!(request_headers_hash),

      file_path: file_path,
      file_size: file_size,
      file_modified_time: file_modified_time,
      file_media_type: media_type,

      response_has_content: true,
      response_is_range: false,
      response_code: HTTP_CODE_OK,
      response_headers: {},
      stop_processing_request_headers: false,
      response_suggested_file_name: suggested_file_name,
      response_disposition_type: disposition_type
    }

    info[:file_entity_tag] = file_entity_tag(info)

    info
  end

  def response_range(info)
    return_value = {}

    return_value[:range_start_bytes] = []
    return_value[:range_end_bytes] = []

    ranges = info[:requested_range].gsub(HTTP_HEADER_ACCEPT_RANGES_BYTES_EQUAL, '').split(',')

    return_value[:is_range] = true
    return_value[:is_multipart] = ranges.size > 1
    return_value[:response_is_range] = true
    return_value[:response_code] = HTTP_CODE_PARTIAL_CONTENT

    start_index = 0
    end_index = 1
    #@max_range_size = 20480

    #  rangeHeader contains the value of the Range HTTP Header and can have values like:
    #      Range: bytes=0-1            * Get bytes 0 and 1, inclusive
    #      Range: bytes=0-500          * Get bytes 0 to 500 (the first 501 bytes), inclusive
    #      Range: bytes=400-1000       * Get bytes 500 to 1000 (501 bytes in total), inclusive
    #      Range: bytes=-200           * Get the last 200 bytes
    #      Range: bytes=500-           * Get all bytes from byte 500 to the end
    #
    # Can also have multiple ranges delimited by commas, as in:
    #      Range: bytes=0-500,600-1000 * Get bytes 0-500 (the first 501 bytes), inclusive plus bytes 600-1000 (401 bytes) inclusive
    #
    # https://tools.ietf.org/html/rfc7233#page-4
    # Byte offsets (start and end) should be inclusive
    # Byte offsets start at 0
    # e.g.
    # The first 500 bytes (byte offsets 0-499, inclusive):
    #    bytes=0-499
    # The second 500 bytes (byte offsets 500-999, inclusive):
    #   bytes=500-999

    return_value[:range_start_bytes] = []
    return_value[:range_end_bytes] = []
    max_end_index = info[:range_end_bytes_max]

    ranges.each do |range|
      current_range = range.split('-')
      start_range = current_range[start_index]
      end_range = current_range[end_index]

      # e.g. "-", ""
      # NB: these technically aren't legal forms (as far as I can tell)
      if start_range.blank? && end_range.blank?
        # default to 0 - @max_range_size (or whatever is available) of file
        start_range = info[:range_start_bytes_min]
        end_range = [@max_range_size + CONVERT_LENGTH_TO_INDEX, max_end_index].min

      # e.g. "0-1", "0-500", "400-1000"
      elsif !start_range.blank? && !end_range.blank?
        # both supplied
        start_range = start_range.to_i
        end_range = end_range.to_i

      # e.g. "500-", "0-"
      elsif !start_range.blank? && end_range.blank?
        # given a start but no end, get the smallest of remaining length and @max_range_size
        start_range = start_range.to_i
        end_range = [start_range + @max_range_size + CONVERT_LENGTH_TO_INDEX, max_end_index].min

      # https://tools.ietf.org/html/rfc7233#page-5
      # assuming a representation of length 10000:
      # The final 500 bytes (byte offsets 9500-9999, inclusive):
      #   bytes=-500
      # e.g. "-200"
      elsif start_range.blank? && !end_range.blank?
        # No beginning specified, get last n bytes of file
        start_range = max_end_index + CONVERT_INDEX_TO_LENGTH - [end_range.to_i, @max_range_size].min
        end_range = max_end_index

      end

      start_range = info[:range_start_bytes_min] if start_range < info[:range_start_bytes_min]
      end_range = max_end_index if end_range > max_end_index
      # e.g. bytes=0-499, max_range_size=500 => 499 - 0 + 1 = 500 > 500
      if (end_range - start_range + CONVERT_INDEX_TO_LENGTH) > @max_range_size
        raise CustomErrors::BadRequestError, 'The requested range exceeded the maximum allowed.'
      end

      if start_range > max_end_index
        # https://datatracker.ietf.org/doc/html/rfc7233#section-4.4
        # Range not satisfiable
        # the current values should equate to zero bytes when we calculate the content length later on
        end_range = start_range + CONVERT_LENGTH_TO_INDEX
      elsif start_range > end_range

        raise CustomErrors::BadRequestError,
          "The requested range specified a first byte `#{start_range}` that was greater than the last byte `#{end_range}`. Requested range: `#{info[:requested_range]}`"
      end

      return_value[:range_start_bytes].push(start_range)
      return_value[:range_end_bytes].push(end_range)
    end

    return_value
  end

  def response_conditions_modified(info)
    return {} if info[:stop_processing_request_headers]

    return_value = {}

    # check If modified since header to determine if file needs to be resent
    if_mod_since = info[:request_headers][HTTP_HEADER_IF_MODIFIED_SINCE]

    unless if_mod_since.blank?
      header_modified_time = Time.zone.parse(if_mod_since)

      # use .to_i so that compares will match even if sub-seconds are removed by Time.zone.parse
      if !header_modified_time.blank? && info[:file_modified_time].getutc.to_i <= header_modified_time.getutc.to_i
        return_value[:response_code] = HTTP_CODE_NOT_MODIFIED
        return_value[:response_is_range] = false
        return_value[:response_has_content] = false
        return_value[:stop_processing_request_headers] = true
      end
    end

    return_value
  end

  def response_conditions_unmodified(info)
    return {} if info[:stop_processing_request_headers]

    return_value = {}

    # check for if unmod since and unless mod since (not quite sure what these headers do or are for)
    if_unmod_since = info[:request_headers][HTTP_HEADER_IF_UNMODIFIED_SINCE]

    if_unmod_since = info[:request_headers][HTTP_HEADER_UNLESS_MODIFIED_SINCE] if if_unmod_since.blank?

    unless if_unmod_since.blank?
      header_time = Time.zone.parse(if_unmod_since)

      # use .to_i so that compares will match even if sub-seconds are removed by Time.zone.parse
      if !header_time.blank? && info[:file_modified_time].getutc.to_i > header_time.getutc.to_i
        # file was created after specified date
        return_value[:response_code] = HTTP_CODE_PRECONDITION_FAILED
        return_value[:response_is_range] = false
        return_value[:response_has_content] = false
        return_value[:stop_processing_request_headers] = true
      end
    end

    return_value
  end

  def response_conditions_etag_match(info)
    return {} if info[:stop_processing_request_headers]

    return_value = {}

    # Check for a match to the ETag
    # If the entity tag given in the If-Range header matches the current entity tag for the entity, then the server
    # SHOULD provide the specified sub-range of the entity using a 206 (Partial content) response. If the entity tag
    # does not match, then the server SHOULD return the entire entity using a 200 (OK) response.
    if_match = info[:request_headers][HTTP_HEADER_IF_MATCH]
    # Only perform the action if the client supplied entity matches the same entity on the server.
    unless if_match.blank?
      entity_ids = if_match.split(',')

      if entity_ids.size == 1 && entity_ids[0] == '*'
        found = true
      else
        found = false
        entity_ids.each do |value|
          if value == info[:file_entity_tag]
            found = true
            break
          end
        end
      end

      unless found
        # did not find a match
        return_value[:response_code] = HTTP_CODE_PRECONDITION_FAILED
        return_value[:response_is_range] = false
        return_value[:response_has_content] = false
        return_value[:stop_processing_request_headers] = true
      end

    end

    return_value
  end

  def response_conditions_etag_no_match(info)
    return {} if info[:stop_processing_request_headers]

    return_value = {}

    # Check if none match header
    if_none_match = info[:request_headers][HTTP_HEADER_IF_NONE_MATCH]
    # Allows a 304 Not Modified to be returned if content is unchanged
    if if_none_match
      if if_none_match == '*'
        # Any etag will match
        return_value[:response_code] = HTTP_CODE_NOT_MODIFIED
        return_value[:response_is_range] = false
        return_value[:response_has_content] = false
        return_value[:stop_processing_request_headers] = true
      else
        entity_ids = if_none_match.split(',')

        entity_ids.each do |value|
          etag_value = value.trim(' ', '')

          next unless etag_value == info[:file_entity_tag]

          return_value[:response_headers] = {}
          return_value[:response_headers][HTTP_HEADER_ENTITY_TAG] = "\"#{etag_value}\""

          return_value[:response_code] = HTTP_CODE_NOT_MODIFIED
          return_value[:response_is_range] = false
          return_value[:response_has_content] = false
          return_value[:stop_processing_request_headers] = true
        end
      end
    end

    return_value
  end

  def response_conditions_range(info)
    return {} if info[:stop_processing_request_headers]

    return_value = {}

    # Check if range header
    if_range = info[:request_headers][HTTP_HEADER_IF_RANGE]
    # If the entity is unchanged, send me the part(s) that I am missing; otherwise, send me the entire new entity
    # change is determined by etag in if-range header
    if !if_range.blank? && if_range != info[:file_entity_tag] && info[:is_range]
      return_value[:response_code] = HTTP_CODE_OK
      return_value[:response_is_range] = false
      return_value[:response_has_content] = true
      return_value[:stop_processing_request_headers] = true
    end

    return_value
  end
end
