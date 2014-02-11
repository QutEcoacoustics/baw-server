class RangeRequest

  MULTIPART_BOUNDARY = '<q1w2e3r4t5y6u7i8o9p0>'
  MULTIPART_CONTENT_TYPE = 'multipart/byteranges boundary=' + MULTIPART_BOUNDARY
  DEFAULT_CONTENT_TYPE = 'application/octet-stream'
  HTTP_HEADER_ACCEPT_RANGES = 'Accept-Ranges'
  HTTP_HEADER_ACCEPT_RANGES_BYTES = 'bytes'
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

  def RangeRequest.request_info(options, rails_request)

    file_path = options[:file_path]
    media_type = options[:media_type]

    range_header = rails_request.headers[HTTP_HEADER_RANGE]

    response_file_abs_start = options[:recorded_date].advance(seconds: options[:start_offset]).strftime('%Y%m%d_%H%M%S')
    response_file_duration = options[:end_offset] - options[:start_offset]

    suggested_file_name =
        "#{options[:site_name].gsub(' ', '_')}_#{response_file_abs_start}_#{response_file_duration}.#{options[:ext]}"


    item = {
        # Indicates if the HTTP request is for multiple ranges.
        is_multipart: false,

        # Indicates if the HTTP request is for one or more ranges.
        is_range: false,

        response_suggested_file_name: suggested_file_name,

        # The start byte(s) for the requested range(s).
        range_start_bytes: [0],

        # The end byte(s) for the requested range(s).
        range_end_bytes: [File.size(file_path)],

        file_path: file_path,
        file_size: File.size(file_path),
        file_entity_tag: RangeRequest.get_entity_tag(file_path),
        file_modified_time: File.mtime(file_path).getutc,
        file_media_type: media_type,

        response_has_content: true,
        response_is_range: false,
        response_code: 200,
        response_headers: {}
    }

    if range_header

      item[:range_start_bytes] = []
      item[:range_end_bytes] = []

      # rangeHeader contains the value of the Range HTTP Header and can have values like:
      #      Range: bytes=0-1            * Get bytes 0 and 1, inclusive
      #      Range: bytes=0-500          * Get bytes 0 to 500 (the first 501 bytes), inclusive
      #     Range: bytes=400-1000       * Get bytes 500 to 1000 (501 bytes in total), inclusive
      #     Range: bytes=-200           * Get the last 200 bytes
      #     Range: bytes=500-           * Get all bytes from byte 500 to the end
      #
      # Can also have multiple ranges delimited by commas, as in:
      #      Range: bytes=0-500,600-1000 * Get bytes 0-500 (the first 501 bytes), inclusive plus bytes 600-1000 (401 bytes) inclusive

      ranges = range_header.gsub('bytes=', '').split(',')

      item[:is_range] = true
      item[:is_multipart] = ranges.size > 1
      item[:response_is_range] = true
      item[:response_code] = 206 # partial content

      start_index = 0
      end_index = 1
      max_range_size = 512000
      #max_range_size = 20480
      subtract_from_size = 1

      ranges.each do |range|
        current_range = range.split('-')
        start_range = current_range[start_index]
        end_range = current_range[end_index]

        if start_range.blank? && end_range.blank?
          # default to first 500kb (or whatever is available) of file
          item[:range_start_bytes] << 0
          item[:range_end_bytes] << [max_range_size, item[:file_size] - subtract_from_size].min

        elsif !start_range.blank? && !end_range.blank?
          # both supplied
          item[:range_start_bytes] << start_range.to_i
          item[:range_end_bytes] << end_range.to_i

        elsif !start_range.blank? && end_range.blank?
          # given a start but no end, get the smallest of remaining length and MaxRangeSize
          item[:range_start_bytes] << start_range.to_i

          remaining_range = [max_range_size, item[:file_size] - subtract_from_size - start_range.to_i].min
          item[:range_end_bytes] << start_range.to_i + remaining_range

        elsif start_range.blank? && !end_range.blank?
          # No beginning specified, get last n bytes of file
          item[:range_start_bytes] << item[:file_size] - subtract_from_size - end_range.to_i
          item[:range_end_bytes] << item[:file_size] - subtract_from_size

        end
      end
    end

    item
  end

  def RangeRequest.process_request(options, rails_request)

    info = RangeRequest.request_info(options, rails_request)

    # auth is performed elsewhere
    # only HTTP get will access this
    # the requested file is check elsewhere (size and whether it exists)

    # check If modified since header to determine if file needs to be resent
    # ==========================================
    if_mod_since = rails_request.headers[HTTP_HEADER_IF_MODIFIED_SINCE]
    unless if_mod_since.blank?
      header_modified_time = Time.parse(if_mod_since).getutc

      if info[:file_modified_time] <= header_modified_time
        info[:response_code] = 304
        info[:response_is_range] = false
        info[:response_has_content] = false
        return info
      end
    end

    # check for if unmod since and unless mod since (not quite sure what these headers do or are for)
    # ==========================================
    if_unmod_since = rails_request.headers[HTTP_HEADER_IF_UNMODIFIED_SINCE]
    if if_unmod_since.blank?
      if_unmod_since = rails_request.headers[HTTP_HEADER_UNLESS_MODIFIED_SINCE]
    end

    unless if_unmod_since.blank?
      header_time = Time.parse(if_unmod_since).getutc

      if info[:file_modified_time] > header_time
        info[:response_code] = 412
        info[:response_is_range] = false
        info[:response_has_content] = false
        return info
      end
    end

    # Check for a match to the ETag
    # ==========================================
    if_match = rails_request.headers[HTTP_HEADER_IF_MATCH]
    # Only perform the action if the client supplied entity matches the same entity on the server.
    if if_match
      entity_ids = if_match.gsub('bytes=', '').split(',')

      found = false
      entity_ids.each do |value|
        if value == info[:file_etag]
          found = true
          break
        end
      end

      unless found
        # did not find a match
        info[:response_code] = 412
        info[:response_is_range] = false
        info[:response_has_content] = false
        return info
      end

    end

    # Check if none match header
    # ==========================================
    if_none_match = rails_request.headers[HTTP_HEADER_IF_NONE_MATCH]
    # Allows a 304 Not Modified to be returned if content is unchanged
    if if_none_match
      if if_none_match == '*'
        # Logically invalid request
        info[:response_code] = 412
        info[:response_is_range] = false
        info[:response_has_content] = false
        return info
      else
        entity_ids = if_none_match.gsub('bytes=', '').split(',')

        entity_ids.each do |value|
          if value == info[:file_etag]
            info[:response_code] = 304
            info[:response_headers][HTTP_HEADER_ENTITY_TAG] = '"' + value + '"'
            info[:response_is_range] = false
            info[:response_has_content] = false
            return info
          end
        end

      end

    end

    # Check if range header
    # ==========================================
    if_range = rails_request.headers[HTTP_HEADER_IF_RANGE]
    # If the entity is unchanged, send me the part(s) that I am missing; otherwise, send me the entire new entity
    # change is determined by etag in if-range header
    if if_range && if_range != info[:file_entity_tag] && info[:is_range]
      info[:response_code] = 200
      info[:response_is_range] = false
      info[:response_has_content] = true
      return info
    end

    info
  end

  def RangeRequest.get_entity_tag(file_path)
    # create the ETag from full file path and last modified date of file
    etag_string = file_path + '|' + File.mtime(file_path).getutc.to_s
    etag = Digest::SHA256.hexdigest etag_string
    etag
  end

  def RangeRequest.prepare_response_partial(info)

    the_number_one = 1
    info[:response_code] = 206 # partial content

    unless info[:is_multipart]
      range_start = info[:range_start_bytes][0]
      range_end = info[:range_end_bytes][0]
      file_size = info[:file_size]
      info[:response_headers][HTTP_HEADER_CONTENT_RANGE] = "bytes #{range_start}-#{range_end}/#{file_size}"
    end

    # calculate content length
    content_length = 0
    info[:range_start_bytes].size.times do |index|
      range_start = info[:range_start_bytes][index]
      range_end = info[:range_end_bytes][index]

      content_length += (range_end - range_start) + the_number_one

      if info[:is_multipart]
        content_length += (
        MULTIPART_BOUNDARY.size +
            info[:file_media_type].size +
            range_start.to_s.size +
            range_end.to_s.size +
            info[:file_size].to_s.size +
            49 # Length needed for multipart header
        )
      end
    end

    if info[:is_multipart]
      # Length of dash and line break
      content_length += MULTIPART_BOUNDARY.size + 8
    end


    # add headers
    info[:response_headers][HTTP_HEADER_CONTENT_LENGTH] = content_length
    info[:response_headers][HTTP_HEADER_CONTENT_TYPE] = info[:is_multipart] ? MULTIPART_CONTENT_TYPE : info[:file_media_type]
    info[:response_headers][HTTP_HEADER_LAST_MODIFIED] = info[:file_modified_time].httpdate()
    info[:response_headers][HTTP_HEADER_ENTITY_TAG] = '"' + info[:file_entity_tag] + '"'
    info[:response_headers][HTTP_HEADER_ACCEPT_RANGES] = HTTP_HEADER_ACCEPT_RANGES_BYTES
    info[:response_headers][HTTP_HEADER_CONTENT_DISPOSITION] = "inline; filename=\"#{info[:response_suggested_file_name]}\""

    info
  end

  def RangeRequest.prepare_response_entire(info)

    info[:response_code] = 200

    info[:response_headers][HTTP_HEADER_CONTENT_LENGTH] = info[:file_size]
    info[:response_headers][HTTP_HEADER_CONTENT_TYPE] = info[:file_media_type]
    info[:response_headers][HTTP_HEADER_LAST_MODIFIED] = info[:file_modified_time].httpdate()
    info[:response_headers][HTTP_HEADER_ENTITY_TAG] = '"' + info[:file_entity_tag] + '"'
    info[:response_headers][HTTP_HEADER_ACCEPT_RANGES] = HTTP_HEADER_ACCEPT_RANGES_BYTES
    info[:response_headers][HTTP_HEADER_CONTENT_DISPOSITION] = "inline; filename=\"#{info[:response_suggested_file_name]}\""

    info
  end

  def RangeRequest.write_content_to_output(info, output_io)

    buffer_size = 10240
    buffer = ''
    the_number_one = 1

    file_name = info[:file_path]

    open(file_name, 'rb') { |file_io| # rb = readonly binary

      info[:range_start_bytes].size.times do |index|
        range_start = info[:range_start_bytes][index].to_i
        range_end = info[:range_end_bytes][index].to_i

        file_io.seek(range_start, IO::SEEK_SET)

        remaining = range_end - range_start + the_number_one

        if info[:is_multipart]
          output_io.write('--'+MULTIPART_BOUNDARY)
          output_io.write("#{HTTP_HEADER_CONTENT_TYPE}: #{info[:file_media_type]}")
          output_io.write("#{HTTP_HEADER_CONTENT_RANGE}: bytes #{range_start}-#{range_end}/#{info[:file_size]}")
          output_io.write('\n')
        end

        while remaining > 0
          # check if client is connected

          # calculate check size
          chunk_size = buffer_size < remaining ? buffer_size : remaining
          data = file_io.read(chunk_size)
          output_io.write(data)

          remaining -= chunk_size
          output_io.flush
        end
      end

      # file is closed by ruby block
    }

  end

end