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

    status.should eq(expected_status), "#{message_prefix} status #{expected_status} but got status #{status}. Response body was #{actual_response}"

    actual_response.should have_json_path(expected_json_path), "#{message_prefix} to find '#{expected_json_path}' in '#{actual_response}'" unless expected_json_path.blank?
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
# @param [String] description
# @param [Symbol] expected_status
# @param [Hash] opts the options for additional information.
# @option opts [String]  :expected_json_path     (nil) Expected json path.
# @option opts [Boolean] :document               (true) Include in api spec documentation.
# @option opts [Symbol]  :response_body_content  (nil) Content that must be in the response body.
# @option opts [Symbol]  :invalid_content        (nil) Content that must not be in the response body.
# @option opts [Symbol]  :data_item_count        (nil) Number of items in a json response
# @option opts [Hash]    :property_match         (nil) Properties to match
# @return [void]
def standard_request_options(description, expected_status, opts = {})
  opts.reverse_merge!({document: true})

  # 406 when you can't send what they want, 415 when they send what you don't want

  example "#{description} - #{expected_status}", :document => opts[:document] do
    do_request
    do_checks(expected_status, opts)
  end
end

# Check response.
# @param [Symbol] expected_status
# @param [Hash] opts the options for additional information.
# @option opts [String] :expected_json_path    (nil) Expected json path.
# @option opts [Symbol] :response_body_content (nil) Content that must be in the response body.
# @option opts [Symbol] :invalid_content       (nil) Content that must not be in the response body.
# @option opts [Symbol] :data_item_count       (nil) Number of items in a json response
# @option opts [Hash]   :property_match        (nil) Properties to match
# @return [void]
def do_checks(expected_status, opts = {})
  opts.reverse_merge!(
      {
          expected_json_path: nil,
          response_body_content: nil,
          invalid_content: nil,
          data_item_count: nil,
          property_match: nil
      })

  actual_response = response_body
  actual_response_parsed = actual_response.blank? ? nil : JsonSpec::Helpers::parse_json(actual_response)
  data_present = !actual_response.blank? &&
      !actual_response_parsed.blank? &&
      actual_response_parsed.include?('data') &&
      !actual_response_parsed['data'].blank?

  data_included = !actual_response.blank? &&
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

  the_request_method = method
  the_request_path = path
  actual_status_code = status
  actual_status = Settings.api_response.status_symbol(actual_status_code)
  expected_status_code = Settings.api_response.status_symbol(expected_status)

  message_prefix = "Requested #{the_request_method} #{the_request_path} expecting"

  expect(expected_status).to eq(actual_status), "#{message_prefix} status #{expected_status} but got status #{actual_status}. Response body was #{actual_response}"

  # this check ensures that there is an assertion when the content is not blank.
  expect(actual_response).to be_blank, "#{message_prefix} blank response, but got #{actual_response}" if opts[:response_body_content].blank? && opts[:expected_json_path].blank?
  expect((data_format == :hash && data_present && actual_response_parsed_size == 1) || !data_present).to be_true, "#{message_prefix} no items in response, but got #{actual_response_parsed_size} items in #{actual_response} (type #{data_format})" if opts[:data_item_count].blank?

  expect(actual_response_parsed_size).to eq(opts[:data_item_count]), "#{message_prefix} count to be #{opts[:data_item_count]} but got #{actual_response_parsed_size} items in #{actual_response} (type #{data_format})" unless opts[:data_item_count].blank?

  expect(actual_response).to include(opts[:response_body_content]), "#{message_prefix} to find '#{opts[:response_body_content]}' in '#{actual_response}'" unless opts[:response_body_content].blank?
  expect(actual_response).to_not include(opts[:invalid_content]), "#{message_prefix} not to find '#{opts[:response_body_content]}' in '#{actual_response}'" unless opts[:invalid_content].blank?

  expect(actual_response).to have_json_path(opts[:expected_json_path]), "#{message_prefix} to find '#{opts[:expected_json_path]}' in '#{actual_response}'" unless opts[:expected_json_path].blank?

  if defined?(expected_unordered_ids) &&
      !expected_unordered_ids.blank? &&
      expected_unordered_ids.is_a?(Array) &&
      data_present &&
      actual_response_parsed['data'].is_a?(Array)

    # RSpec also provides a =~ matcher for arrays that disregards differences in
    # the ordering between the actual and expected array.
    actual_ids = actual_response_parsed['data'].map { |x| x.include?('id') ? x.id : nil }
    actual_ids.should =~ expected_unordered_ids

    # actual_response_parsed.each_index do |index|
    #   expect(actual_response_parsed[index]['audio_event_id'])
    #   .to eq(opts[:unordered_ids][index]),
    #       "Result body index #{index} in #{opts[:unordered_ids]}: #{actual_response_parsed}"
    # end
    # opts[:unordered_ids].each_index do |index|
    #   expect(opts[:unordered_ids][index])
    #   .to eq(actual_response_parsed[index]['audio_event_id']),
    #       "Audio Event Order index #{index} in #{opts[:unordered_ids]}: #{actual_response_parsed}"
    # end
  end

  unless opts[:property_match].nil?
    opts[:property_match].each do |key, value|
      expect(actual_response_parsed['data']).to include(key.to_s)
      expect(actual_response_parsed['data'][key.to_s].to_s).to eq(value.to_s)
    end
  end

end

def check_site_lat_long_response(description, expected_status, should_be_obfuscated = true)
  example "#{description} - #{expected_status}", document: false do
    do_request
    status.should eq(expected_status), "Requested #{path} expecting status #{expected_status} but got status #{status}. Response body was #{response_body}"
    response_body.should have_json_path('location_obfuscated'), response_body.to_s
    #response_body.should have_json_type(Boolean).at_path('location_obfuscated'), response_body.to_s
    site = JSON.parse(response_body)

    #'Accurate to with a kilometre (± 1000m)'

    lat = site['latitude']
    long = site['longitude']

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
    actual.should have_json_path(expected_json_path), "Expected #{expected_json_path} in #{actual}"
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

def remove_media_dirs(media_cacher)
  FileUtils.rm_r media_cacher.cache.original_audio.storage_paths.first if Dir.exists? media_cacher.cache.original_audio.storage_paths.first
  FileUtils.rm_r media_cacher.cache.cache_audio.storage_paths.first if Dir.exists? media_cacher.cache.cache_audio.storage_paths.first
  FileUtils.rm_r media_cacher.cache.cache_spectrogram.storage_paths.first if Dir.exists? media_cacher.cache.cache_spectrogram.storage_paths.first
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

  original_file_names = media_cacher.original_audio_file_names(options)
  original_possible_paths = original_file_names.map { |source_file| media_cacher.cache.possible_storage_paths(media_cacher.cache.original_audio, source_file) }.flatten

  FileUtils.mkpath File.dirname(original_possible_paths.first)
  FileUtils.cp audio_file_mono, original_possible_paths.first

  options
end

def validate_media_response(content_type, check_accept_header = true)
  status.should eq(200), "expected status 200 but was #{status}. Response body was #{response_body}"
  response_headers['Content-Type'].should include(content_type)
  response_headers['Accept-Ranges'].should eq('bytes') if check_accept_header

  response_headers['Content-Transfer-Encoding'].should eq('binary') unless content_type == 'application/json'
  response_headers['Content-Transfer-Encoding'].should be_nil if content_type == 'application/json'

  response_headers['Content-Disposition'].should start_with('inline; filename=') unless content_type == 'application/json'
  response_headers['Content-Disposition'].should be_nil if content_type == 'application/json'
end

def check_common_request_items(audio_recording, content_type, check_accept_header = true)

  options = create_media_options(audio_recording)

  request = do_request


  [options, request]
end

def using_original_audio(audio_recording, content_type, check_accept_header = true, check_content_length = true, expected_head_request = false)
  options, request = check_common_request_items(audio_recording, content_type, check_accept_header)
  using_original_audio_custom(options, request, audio_recording, check_accept_header, check_content_length, expected_head_request)
end

def using_original_audio_custom(options, request, audio_recording, check_accept_header = true, check_content_length = true, expected_head_request = false)
  is_image = response_headers['Content-Type'].include? 'image'
  default_spectrogram = Settings.cached_spectrogram_defaults

  is_audio = response_headers['Content-Type'].include? 'audio'
  default_audio = Settings.cached_audio_defaults

  # !! - forces the boolean context, but returns the proper boolean value
  is_documentation_run = !!(ENV['GENERATE_DOC'])

  actual_head_request = !is_documentation_run && !request.blank? && !request[0].blank? && request[0][:request_method] == 'HEAD'

  # assert
  if actual_head_request || expected_head_request
    response_body.size.should eq(0)
    if is_image
      options[:format] = default_spectrogram.extension
      options[:channel] = default_spectrogram.channel.to_i
      options[:sample_rate] = default_spectrogram.sample_rate.to_i
      options[:window] = default_spectrogram.window.to_i
      options[:window_function] = default_spectrogram.window_function.to_i
      options[:colour] = default_spectrogram.colour.to_s
      cache_spectrogram_file = media_cacher.cached_spectrogram_file_name(options)
      cache_spectrogram_possible_paths = media_cacher.cache.possible_storage_paths(media_cacher.cache.cache_spectrogram, cache_spectrogram_file)
      response_headers['Content-Length'].to_i.should eq(File.size(cache_spectrogram_possible_paths.first)) if check_content_length
    elsif is_audio
      options[:format] = default_audio.extension
      options[:channel] = default_audio.channel.to_i
      options[:sample_rate] = default_audio.sample_rate.to_i
      cache_audio_file = media_cacher.cached_audio_file_name(options)
      cache_audio_possible_paths = media_cacher.cache.possible_storage_paths(media_cacher.cache.cache_audio, cache_audio_file)
      response_headers['Content-Length'].to_i.should eq(File.size(cache_audio_possible_paths.first)) if check_content_length
    elsif response_headers['Content-Type'].include? 'application/json'
      response_headers['Content-Length'].to_i.should be > 0
      # TODO: files should not exist?
    else
      fail "Unrecognised content type: #{response_headers['Content-Type']}"
    end
  else
    begin
      temp_file = File.join(Settings.paths.temp_files, 'temp-media_controller_response')
      File.open(temp_file, 'wb') { |f| f.write(response_body) }
      response_headers['Content-Length'].to_i.should eq(File.size(temp_file))
    ensure
      File.delete temp_file if File.exists? temp_file
    end
  end
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