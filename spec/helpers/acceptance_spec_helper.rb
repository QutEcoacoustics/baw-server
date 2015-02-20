def document_media_requests
  # this is here so rspec_api_documentation can be generated
  # any request that returns content that cannot be json serialised (e.g. binary data)
  # will cause generating the documentation to fail
  if ENV['GENERATE_DOC']
    false
  else
    true
  end
end

def standard_request(description, expected_status, expected_json_path = nil, document = true, response_body_content = nil, invalid_content = nil)
  # Execute request with ids defined in above let(:id) statements
  example "#{description} - #{expected_status}", :document => document do
    do_request

    actual_response = response_body
    the_request_method = method
    the_request_path = path

    message_prefix = "Requested #{the_request_method} #{the_request_path} expecting"

    expect(status).to eq(expected_status), "#{message_prefix} status #{expected_status} but got status #{status}. Response body was #{actual_response}"

    expect(actual_response).to have_json_path(expected_json_path), "#{message_prefix} to find '#{expected_json_path}' in '#{actual_response}'" unless expected_json_path.blank?
    # this check ensures that there is an assertion when the content is not blank.
    #expect(actual_response).to be_blank, "#{message_prefix} blank response, but got #{actual_response}" if response_body_content.blank? && expected_json_path.blank?
    expect(actual_response).to include(response_body_content), "#{message_prefix} to find '#{response_body_content}' in '#{actual_response}'" unless response_body_content.blank?
    expect(actual_response).to_not include(invalid_content), "#{message_prefix} not to find '#{response_body_content}' in '#{actual_response}'" unless invalid_content.blank?

    # 406 when you can't send what they want, 415 when they send what you don't want

    if block_given?
      yield(actual_response)
    end

    actual_response
  end
end

# Execute the example.
# @param [String] http_method
# @param [String] description
# @param [Symbol] expected_status
# @param [Hash] opts the options for additional information.
# @option opts [String]  :expected_json_path     (nil) Expected json path.
# @option opts [Boolean] :document               (true) Include in api spec documentation.
# @option opts [Symbol]  :response_body_content  (nil) Content that must be in the response body.
# @option opts [Symbol]  :invalid_content        (nil) Content that must not be in the response body.
# @option opts [Symbol]  :data_item_count        (nil) Number of items in a json response
# @option opts [Hash]    :property_match         (nil) Properties to match
# @option opts [Hash]    :file_exists            (nil) Check if file exists
# @option opts [Class]   :expected_error_class   (nil) The expected error class
# @option opts [Regexp]  :expected_error_regexp  (nil) The expected error regular expression
# @return [void]
def standard_request_options(http_method, description, expected_status, opts = {})
  opts.reverse_merge!({document: true})

  # 406 when you can't send what they want, 415 when they send what you don't want

  example "#{http_method} #{description} - #{expected_status}", :document => opts[:document] do

    if defined?(include_test_file) && include_test_file
      uuid = audio_recording.uuid
      path = "./tmp/_cached_analysis_jobs/#{uuid[0, 2].downcase}/#{uuid.downcase}/Test/test-CASE.csv"

      FileUtils.mkpath File.dirname(path)
      File.open(path, 'w') { |f| f.write('{"content":"This is some content."}') }
    end

    expected_error_class = opts[:expected_error_class]
    expected_error_regexp = opts[:expected_error_regexp]
    problem = (expected_error_class.blank? && !expected_error_regexp.blank?) ||
        (!expected_error_class.blank? && expected_error_regexp.blank?)

    fail "Specify both expected_error_class and expected_error_regexp" if problem

    if !expected_error_class.blank? && !expected_error_regexp.blank?
      expect {
        do_request
      }.to raise_error(expected_error_class, expected_error_regexp)
    else
      request = do_request

      opts.merge!(
          {
              expected_status: expected_status,
              expected_method: http_method
          })

      opts = acceptance_checks_shared(request, opts)
      acceptance_checks_json(opts)

    end

  end
end

# Execute the media request example.
# @param [String] http_method
# @param [String] description
# @param [Symbol] expected_status
# @param [Hash] opts the options for additional information.
# @option opts [String]  :content_type           ('text/plain') Expected content type.
# @option opts [Boolean] :document               (true) Include in api spec documentation.
# @option opts [Boolean] :check_accept_header    (true) Check the Accept header.
# @option opts [Boolean] :check_content_length   (true) Check the Content-Length header.
# @return [void]
def media_request_options(http_method, description, expected_status, opts = {})
  opts.reverse_merge!({document: true})

  example "#{http_method} #{description} - #{expected_status}", document: opts[:document] do
    options = create_media_options(audio_recording)
    request = do_request

    opts.merge!(
        {
            expected_status: expected_status,
            expected_method: http_method
        })

    opts = acceptance_checks_shared(request, opts)

    opts.merge!({audio_recording: options})
    acceptance_checks_media(opts)
  end
end

# Check response.
# @param [Object] request
# @param [Hash] opts the options for additional information.
# @option opts [String, Symbol] :expected_status                 (nil) Expected http status.
# @option opts [String]         :expected_method                 (nil) Expected http method.
# @option opts [Boolean]        :expected_response_has_content   (nil) Is the response expected to have content?
# @option opts [String]         :expected_response_content_type  (nil) What is the expected response content type?
# @option opts [Hash]           :expected_response_header_values (nil) The expected response headers and values (keys and values are strings)
# @option opts [Boolean]        :expected_response_header_values_match (true) Should the response headers match the provided hash exactly?
# @option opts [Hash]           :expected_request_header_values  (nil) The expected request headers and values (keys and values are strings)
# @return [void]
def acceptance_checks_shared(request, opts = {})
  opts.reverse_merge!(
      {
          expected_status: :ok,
          expected_method: :get,

          expected_response_has_content: true,
          expected_response_content_type: 'application/json',

          # @option opts [String]         :expected_request_content_type   (nil) What is the expected request content type?
          #expected_request_content_type: 'application/json'

          expected_response_header_values_match: true
      })

  # Rubymine might think this is an error - it's fine, there are so many methods named 'method' :/
  http_method = method

  # !! - forces the boolean context, but returns the proper boolean value
  # don't document because it returns binary data that can't be json encoded
  #is_documentation_run = !!(ENV['GENERATE_DOC'])

  actual_response = response_body

  # info hash
  opts.merge!(
      {
          #is_documentation_run: is_documentation_run,

          actual_method: http_method,
          actual_status: status.is_a?(Symbol) ? status : Settings.api_response.status_symbol(status),
          actual_query_string: query_string,
          actual_path: path,

          actual_response: actual_response,
          actual_response_has_content: !actual_response.empty?,
          actual_response_headers: response_headers,
          actual_response_content_type: response_headers['Content-Type'],

          #actual_request_content_type: request_headers['Content-Type'],
          actual_request_headers: (request.nil? || request.size < 1) ? nil : request[0][:request_headers],

          expected_status: opts[:expected_status].is_a?(Symbol) ? opts[:expected_status] : Settings.api_response.status_symbol(opts[:expected_status]),
      })

  opts[:msg] = "Requested #{opts[:actual_method]} #{opts[:actual_path]}. Information hash: #{opts}"

  # expectations
  expect(opts[:actual_status]).to eq(opts[:expected_status]), "Mismatch: status. #{opts[:msg]}"
  expect(opts[:actual_method]).to eq(opts[:expected_method]), "Mismatch: HTTP method. #{opts[:msg]}"

  #expect(opts[:expected_request_content_type]).to eq(opts[:actual_request_content_type]), "Mismatch: request content type. #{opts[:msg]}"
  expect(opts[:actual_response_has_content]).to eq(opts[:expected_response_has_content]), "Mismatch: response has content. #{opts[:actual_response]} #{opts[:msg]}"
  if opts[:actual_response_content_type].blank?
    expect(opts[:expected_response_content_type]).to be_nil, "Mismatch: response content type. #{opts[:msg]}"
  elsif opts.include?(:actual_response_content_type)
    expect(opts[:actual_response_content_type]).to include(opts[:expected_response_content_type]), "Mismatch: response content type. #{opts[:msg]}"
  end

  if !opts[:actual_response_content_type].blank? && opts[:actual_response_content_type] == 'application/json'
    expect(opts[:actual_response_headers]['Content-Transfer-Encoding']).to be_nil, "Mismatch: content transfer encoding. #{opts[:msg]}"
    expect(opts[:actual_response_headers]['Content-Disposition']).to be_nil, "Mismatch: content disposition. #{opts[:msg]}"
  end

  if !opts[:actual_response_content_type].blank? && (opts[:actual_response_content_type].start_with?('image/') ||
      opts[:actual_response_content_type].start_with?('audio/'))
    expect(opts[:actual_response_headers]['Content-Transfer-Encoding']).to eq('binary'), "Mismatch: content transfer encoding. #{opts[:msg]}"
    expect(opts[:actual_response_headers]['Content-Disposition']).to start_with('inline; filename='), "Mismatch: content disposition. #{opts[:msg]}"
  end

  unless opts[:expected_request_header_values].blank?
    expected_request_headers = opts[:expected_request_header_values]
    actual_request_headers = opts[:actual_request_headers]
    expected_request_headers.each do |key, value|
      expect(actual_request_headers.keys).to include(key), "Mismatch: Did not find '#{key}' in request headers: #{actual_request_headers.keys.join(', ')}."
      expect(actual_request_headers[key]).to eq(value), "Mismatch: Value '#{actual_request_headers[key].inspect}' for '#{key}' in request headers did not match expected value #{value.inspect}."
    end

    difference = actual_request_headers.keys - expected_request_headers.keys
    expect(difference).to be_empty, "Mismatch: request headers differ by #{difference}: \nExpected: #{expected_request_headers} \nActual: #{actual_request_headers}"


  end

  unless opts[:expected_response_header_values].blank?
    expected_response_headers = opts[:expected_response_header_values]
    actual_response_headers = opts[:actual_response_headers]

    expected_response_headers.each do |key, value|
      expect(actual_response_headers).to include(key), "Mismatch: Did not find '#{key}' in response headers: #{actual_response_headers.keys.join(', ')}."
      expect(actual_response_headers[key]).to eq(value), "Mismatch: Value '#{actual_response_headers[key].inspect}' for '#{key}' in response headers did not match expected value #{value.inspect}."
    end

    if opts[:expected_response_header_values_match]
    difference = actual_response_headers.keys - expected_response_headers.keys
    expect(difference).to be_empty, "Mismatch: response headers differ by #{difference}: \nExpected: #{expected_response_headers} \nActual: #{actual_response_headers}"
      end
  end

  opts
end

# Check json response.
# @param [Hash] opts the options for additional information.
# @option opts [String] :expected_json_path    (nil) Expected json path.
# @option opts [Symbol] :response_body_content (nil) Content that must be in the response body.
# @option opts [Symbol] :invalid_content       (nil) Content that must not be in the response body.
# @option opts [Symbol] :data_item_count       (nil) Number of items in a json response
# @option opts [Hash]   :property_match        (nil) Properties to match
# @option opts [Regex]  :regex_match           (nil) Regex that must match content
# @return [void]
def acceptance_checks_json(opts = {})
  opts.reverse_merge!(
      {
          expected_json_path: nil,
          response_body_content: nil,
          invalid_content: nil,
          data_item_count: nil,
          property_match: nil,
          regex_match: nil
      })

  actual_response_parsed = opts[:actual_response].blank? ? nil : JsonSpec::Helpers::parse_json(opts[:actual_response])
  data_present = !opts[:actual_response].blank? &&
      !actual_response_parsed.blank? &&
          actual_response_parsed.include?('data') &&
          !actual_response_parsed['data'].blank?

  data_included = !opts[:actual_response].blank? &&
      !actual_response_parsed.blank? &&
          actual_response_parsed.include?('data')


  if data_included && actual_response_parsed['data'].is_a?(Array)
    actual_response_parsed_size = actual_response_parsed['data'].size
    data_format = :array
  elsif data_included && actual_response_parsed['data'].is_a?(Hash)
    actual_response_parsed_size = 1
    data_format = :hash
  else
    actual_response_parsed_size = nil
    data_format = nil
  end

  message_prefix = "Requested #{opts[:actual_method]} #{opts[:actual_path]} expecting"

  # this check ensures that there is an assertion when the content is not blank.
  expect(opts[:actual_response]).to be_blank, "#{message_prefix} blank response, but got #{opts[:actual_response]}" if opts[:response_body_content].blank? && opts[:expected_json_path].blank?
  expect((data_format == :hash && data_present && actual_response_parsed_size == 1) || !data_present).to be_truthy, "#{message_prefix} no items in response, but got #{actual_response_parsed_size} items in #{opts[:actual_response]} (type #{data_format})" if opts[:data_item_count].blank?

  expect(actual_response_parsed_size).to eq(opts[:data_item_count]), "#{message_prefix} count to be #{opts[:data_item_count]} but got #{actual_response_parsed_size} items in #{opts[:actual_response]} (type #{data_format})" unless opts[:data_item_count].blank?

  expect(opts[:actual_response]).to include(opts[:response_body_content]), "#{message_prefix} to find '#{opts[:response_body_content]}' in '#{opts[:actual_response]}'" unless opts[:response_body_content].blank?
  expect(opts[:actual_response]).to_not include(opts[:invalid_content]), "#{message_prefix} not to find '#{opts[:response_body_content]}' in '#{opts[:actual_response]}'" unless opts[:invalid_content].blank?

  unless opts[:expected_json_path].blank?

    expected_json_path_array = []
    if opts[:expected_json_path].is_a?(Array)
      expected_json_path_array = opts[:expected_json_path]
    else
      opts[:expected_json_path] = [opts[:expected_json_path]]
    end

    opts[:expected_json_path].each do |expected_json_path_item|
      expect(opts[:actual_response]).to have_json_path(expected_json_path_item), "#{message_prefix} to find '#{expected_json_path_item}' in '#{opts[:actual_response]}'"
    end

  end

  if defined?(expected_unordered_ids) &&
      !expected_unordered_ids.blank? &&
          expected_unordered_ids.is_a?(Array) &&
          data_present &&
          actual_response_parsed['data'].is_a?(Array)

    actual_ids = actual_response_parsed['data'].map { |x| x.include?('id') ? x['id'] : nil }
    expect(actual_ids).to match_array(expected_unordered_ids)

  end

  unless opts[:property_match].nil?
    opts[:property_match].each do |key, value|
      expect(actual_response_parsed['data']).to include(key.to_s)
      expect(actual_response_parsed['data'][key.to_s].to_s).to eq(value.to_s)
    end
  end

  unless opts[:regex_match].nil?
    expect(opts[:actual_response]).to match(opts[:regex_match])
  end

end

# Check media response.
# @param [Hash] opts the options for additional information.
# @option opts [Boolean] :accepts_range_request    (nil) Is a range request expected?
# @return [void]
def acceptance_checks_media(opts = {})
  opts.reverse_merge!(
      {
          is_range_request: false,
          expected_response_media_from_header: 'Generated Locally'
      })

  is_image = opts[:actual_response_headers]['Content-Type'].include? 'image'
  default_spectrogram = Settings.cached_spectrogram_defaults

  is_audio = opts[:actual_response_headers]['Content-Type'].include? 'audio'
  default_audio = Settings.cached_audio_defaults

  is_json = opts[:actual_response_headers]['Content-Type'].include? 'application/json'

  if is_audio
    expect(opts[:actual_response_headers]).to include('Accept-Ranges'), "Missing header: accept ranges. #{opts[:msg]}"
    expect(opts[:actual_response_headers]['Accept-Ranges']).to eq('bytes'), "Mismatch: accept ranges. #{opts[:msg]}"
  else
    expect(opts[:actual_response_headers]['Accept-Ranges']).to be_nil, "Mismatch: accept ranges. #{opts[:msg]}"
  end

  expect(opts[:actual_response_headers]).to include('Content-Length'), "Missing header: content length. #{opts[:msg]}"
  expect(opts[:actual_response_headers]['Content-Length']).to_not be_blank, "Mismatch: content length. #{opts[:msg]}"

  if is_json
    expect(opts[:actual_response_headers]).to_not include(*MediaPoll::HEADERS_EXPOSED - ['Content-Length']), "One or more of these headers was present when it should not be #{MediaPoll::HEADERS_EXPOSED} #{opts[:msg]}"
  else
    expect(opts[:actual_response_headers]).to include(*MediaPoll::HEADERS_EXPOSED), "Missing one or more of these headers #{MediaPoll::HEADERS_EXPOSED} #{opts[:msg]}"
  end

  if opts[:is_range_request]
    expect(opts[:actual_response_headers]).to include('Content-Range'), "Missing header: content range. #{opts[:msg]}"
    expect(opts[:actual_response_headers]['Content-Range']).to include('bytes 0-'), "Mismatch: content range. #{opts[:msg]}"
  else
    expect(opts[:actual_response_headers]['Content-Range']).to be_nil, "Mismatch: content range. #{opts[:msg]}"
  end

  # assert
  if opts[:actual_method] == :head || opts[:expected_method] == :head
    expect(opts[:actual_response].size).to eq(0), "Mismatch: actual response size. #{opts[:msg]}"
    options = opts[:audio_recording] || {}
    if is_image
      options[:format] = default_spectrogram.extension
      options[:channel] = default_spectrogram.channel.to_i
      options[:sample_rate] = default_spectrogram.sample_rate.to_i
      options[:window] = default_spectrogram.window.to_i
      options[:window_function] = default_spectrogram.window_function
      options[:colour] = default_spectrogram.colour.to_s

      cache_spectrogram_possible_paths = spectrogram_cache.possible_paths(options)

      if opts[:expected_response_has_content]
        expect(opts[:actual_response_headers]['Content-Length'].to_i).to eq(File.size(cache_spectrogram_possible_paths.first)),
                                                                         "Mismatch: response image length. #{opts[:msg]}"
      end
    elsif is_audio
      options[:format] = default_audio.extension
      options[:channel] = default_audio.channel.to_i
      options[:sample_rate] = default_audio.sample_rate.to_i

      cache_audio_possible_paths = audio_cache.possible_paths(options)

      if opts[:expected_response_has_content]
        expect(opts[:actual_response_headers]['Content-Length'].to_i).to eq(File.size(cache_audio_possible_paths.first)),
                                                                         "Mismatch: response audio length. #{opts[:msg]}"
      end
    elsif is_json
      expect(opts[:actual_response_headers]['Content-Length'].to_i).to be > 0,
                                                                       "Mismatch: actual media json length. #{opts[:msg]}"
      # TODO: files should not exist?
    else
      fail "Unrecognised content type: #{opts[:actual_response_headers]['Content-Type']}"
    end
  else
    begin
      temp_file = File.join(Settings.paths.temp_dir, 'temp-media_controller_response')
      File.open(temp_file, 'wb') { |f| f.write(response_body) }
      expect(opts[:actual_response_headers]['Content-Length'].to_i).to eq(File.size(temp_file)),
                                                                       "Mismatch: actual media length. #{opts[:msg]}"
    ensure
      File.delete temp_file if File.exists? temp_file
    end
  end
end

def check_site_lat_long_response(description, expected_status, should_be_obfuscated = true)
  example "#{description} - #{expected_status}", document: false do
    do_request
    status.should eq(expected_status), "Requested #{path} expecting status #{expected_status} but got status #{status}. Response body was #{response_body}"
    response_body.should have_json_path('data/location_obfuscated'), response_body.to_s
    #response_body.should have_json_type(Boolean).at_path('location_obfuscated'), response_body.to_s
    site = JSON.parse(response_body)
    lat = site['data']['custom_latitude']
    long = site['data']['custom_longitude']

    #'Accurate to with a kilometre (± 1000m)'

    stored_site = Site.where(id: site['data']['id']).first
    stored_site_lat = stored_site.latitude
    stored_site_long = stored_site.longitude

    if site['data']['location_obfuscated']
      # assume that jitter will not result in the same number twice
      expect(stored_site_lat).not_to be_within(0.00001).of(lat)
      expect(stored_site_long).not_to be_within(0.00001).of(long)
    else
      # numbers should be the same
      expect(stored_site_lat).to be_within(0.00001).of(lat)
      expect(stored_site_long).to be_within(0.00001).of(long)
    end

    if should_be_obfuscated
      min = 3
      max = 6
      expect(lat.to_s.split('.').last.size)
          .to satisfy { |v| v >= min && v <= max },
              "expected latitude to be obfuscated to between #{min} to #{max} places, "+
                  "got #{lat.to_s.split('.').last.size} from #{lat}"

      expect(long.to_s.split('.').last.size)
          .to satisfy { |v| v >= min && v <= max },
              "expected longitude to be obfuscated to between #{min} to #{max} places, "+
                  "got #{long.to_s.split('.').last.size} from #{long}"
    end
  end
end

def find_unexpected_entries(parent, hash, remaining_to_match, not_included)
  hash.each { |key, value|

    new_parent = parent
    if parent.nil?
      new_parent = key
    else
      new_parent = parent + '/' + key
    end

    unless remaining_to_match.include?(new_parent)
      not_included.push(new_parent)
    end

    if value.is_a?(Hash)
      find_unexpected_entries(new_parent, value, remaining_to_match, not_included)
    end
  }
  not_included
end

def check_hash_matches(expected, actual)
  expected.each do |expected_json_path|
    expect(actual).to have_json_path(expected_json_path), "Expected #{expected_json_path} in #{actual}"
  end

  parsed = JsonSpec::Helpers::parse_json(actual)
  remaining = find_unexpected_entries(nil, parsed, expected.dup, [])
  expect(remaining).to be_empty, "expected no additional elements, got #{remaining}."
end


def standard_media_parameters

  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

  parameter :format, 'Required format of the audio segment (options: json|mp3|flac|webm|ogg|wav|png). Use json if requesting metadata', required: true
  parameter :start_offset, 'Start time of the audio segment in seconds'
  parameter :end_offset, 'End time of the audio segment in seconds'

  let(:start_offset) { '1' }
  let(:end_offset) { '2' }

  let(:raw_post) { params.to_json }
end

def remove_media_dirs
  audio_original.existing_dirs.each { |dir| FileUtils.rm_r dir }
  audio_cache.existing_dirs.each { |dir| FileUtils.rm_r dir }
  spectrogram_cache.existing_dirs.each { |dir| FileUtils.rm_r dir }
  analysis_cache.existing_dirs.each { |dir| FileUtils.rm_r dir }
end

def create_media_options(audio_recording)
  options = {}
  options[:datetime] = audio_recording.recorded_date
  options[:original_format] = File.extname(audio_recording.original_file_name) unless audio_recording.original_file_name.blank?
  options[:original_format] = '.' + Mime::Type.lookup(audio_recording.media_type).to_sym.to_s if options[:original_format].blank?
  options[:datetime_with_offset] = audio_recording.recorded_date
  options[:uuid] = audio_recording.uuid
  options[:id] = audio_recording.id
  options[:start_offset] = start_offset unless start_offset.blank?
  options[:end_offset] = end_offset unless end_offset.blank?

  original_possible_paths = audio_original.possible_paths(options)

  FileUtils.mkpath File.dirname(original_possible_paths.first)
  FileUtils.cp audio_file_mono, original_possible_paths.first

  options
end

def emulate_resque_worker_with_job(job_class, job_args, opts={})
  # see http://stackoverflow.com/questions/5141378/how-to-bridge-the-testing-using-resque-with-rspec-examples
  queue = opts[:queue] || 'test_queue'

  Resque::Job.create(queue, job_class, *job_args)

  emulate_resque_worker(queue, opts[:verbose], opts[:fork])
end

def emulate_resque_worker(queue, verbose, fork)
  queue = queue || 'test_queue'

  worker = Resque::Worker.new(queue)
  worker.very_verbose = true if verbose

  if fork
    # do a single job then shutdown
    def worker.done_working
      super
      shutdown
    end

    worker.work(0.5)
  else
    job = worker.reserve
    worker.perform(job)
  end
end

def process_custom(method, path, params = {}, headers ={})
  do_request(method, path, params, headers)
  document_example(method.to_s.upcase, path)
end