require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def library_request(settings = {})
  description = settings[:description]
  expected_status = settings[:expected_status]
  expected_json_path = settings[:expected_json_path]
  document = settings[:document]
  response_body_content = settings[:response_body_content]

  example "#{description} - #{expected_status}", :document => document do
    do_request

    expect(status).to eq(expected_status), "Requested #{path} expecting status #{expected_status} but got status #{status}. Response body was #{response_body}"

    unless expected_json_path.blank?
      response_body.should have_json_path(expected_json_path), "could not find #{expected_json_path} in #{response_body}"
    end

    unless response_body_content.blank?
      expect(response_body).to include(response_body_content)
    end

    parsed_response_body = JsonSpec::Helpers::parse_json(response_body)

    if !ordered_audio_recordings.blank? && ordered_audio_recordings.respond_to?(:each_index) &&
        !parsed_response_body.blank? && parsed_response_body.respond_to?(:each_index)
      parsed_response_body.each_index do |index|
        expect(parsed_response_body[index]['audio_event_id'])
            .to eq(ordered_audio_recordings[index]),
                "Result body index #{index} in #{ordered_audio_recordings}: #{parsed_response_body}"
      end
      ordered_audio_recordings.each_index do |index|
        expect(ordered_audio_recordings[index])
            .to eq(parsed_response_body[index]['audio_event_id']),
                "Audio Event Order index #{index} in #{ordered_audio_recordings}: #{parsed_response_body}"
      end
    end

  end
end

# https://github.com/zipmark/rspec_api_documentation
resource 'AudioEvents' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  create_entire_hierarchy

  let!(:existing_tag) { FactoryGirl.create(:tag, text: 'existing') }

  let(:audio_recording_id) { audio_recording.id }
  let(:id) { audio_event.id }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:audio_event) }
  let(:post_nested_attributes) {
    {tags_attributes: [
        FactoryGirl.attributes_for(:tag),
        {
            is_taxanomic: existing_tag.is_taxanomic,
            text: existing_tag.text,
            type_of_tag: existing_tag.type_of_tag,
            retired: existing_tag.retired
        }
    ]}
  }

  ################################
  # LIST
  ################################
  get '/audio_recordings/:audio_recording_id/audio_events' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'LIST (as writer)', :ok, {expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})

  end

  get '/audio_recordings/:audio_recording_id/audio_events' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader)', :ok, {expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})

  end


  get '/audio_recordings/:audio_recording_id/audio_events' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader with shallow path)', :ok, {expected_json_path: 'data/0/start_time_seconds', data_item_count: 1})

  end

  get '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { unconfirmed_token }

    standard_request_options(:get, 'LIST (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})

  end

  get '/audio_recordings/:audio_recording_id/audio_events' do

    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :start_offset, 'Request audio events within offset bounds (start)'
    parameter :end_offset, 'Request audio events within offset bounds (end)'

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'LIST (as reader with shallow path testing quoted numbers)', :ok,
                             {
                                 data_item_count: 1,
                                 expected_json_path: 'data/0/start_time_seconds',
                                 response_body_content: ['"start_time_seconds":5.2,',
                                                         '"end_time_seconds":5.8,',
                                                         '"low_frequency_hertz":400.0,',
                                                         '"high_frequency_hertz":6000.0'
                                 ]
                             })

  end

  ################################
  # SHOW
  ################################
  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request_options(:get, 'SHOW (as writer)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request_options(:get, 'SHOW (as reader with shallow path)', :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }

    let(:id) { @audio_event.id }
    let(:audio_recording_id) { @other_audio_recording_id }

    before do
      @other_audio_recording_id = project.sites[0].audio_recordings[0].id
      @audio_event = FactoryGirl.create(:audio_event, audio_recording_id: @other_audio_recording_id, start_time_seconds: 5, end_time_seconds: 6, is_reference: true)
    end

    standard_request_options(:get, 'SHOW (as reader with shallow path for reference audio event with no access to audio recording)',
                             :ok, {expected_json_path: 'data/start_time_seconds'})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token }

    standard_request_options(:get, 'SHOW (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  get '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }


    standard_request_options(:get, 'SHOW (as reader with shallow path testing quoted numbers)', :ok,
                             {
                                 expected_json_path: 'data/start_time_seconds',
                                 response_body_content: ['"start_time_seconds":5.2,',
                                                         '"end_time_seconds":5.8,',
                                                         '"high_frequency_hertz":6000.0,',
                                                         '"low_frequency_hertz":400.0']
                             })
  end

  ################################
  # CREATE
  ################################
  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { admin_token }

    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/is_reference'})

  end

  post 'audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/is_reference'})

  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request_options(:post, 'CREATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})

  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { unconfirmed_token }

    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})

  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event
    parameter :tags_attributes, 'array of valid tag attributes, see tag resource', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes.merge(post_nested_attributes)}.to_json }
    let(:authentication_token) { writer_token }

    #standard_request_options(: ,'CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
    example 'CREATE (with tags_attributes (one existing tag text, one new) as writer) - 201', :document => true do
      explanation 'this should create an audiorecording, including two taggings, one with the newly created tag and one with an existing tag'
      tag_count = Tag.count
      request = do_request

      # expecting two 'taggings'

      # check response
      opts =
          {
              expected_status: :created,
              expected_method: :post,
              expected_response_content_type: 'application/json',
              document: document_media_requests
          }

      opts = acceptance_checks_shared(request, opts)

      opts.merge!({expected_json_path: 'data/taggings/1/tag_id', response_body_content: 'start_time_seconds'})
      acceptance_checks_json(opts)

      # only one tag should have been created, so new tag count should be one more than old tag count
      expect(tag_count).to eq(Tag.count - 1)
    end
  end

  post '/audio_recordings/:audio_recording_id/audio_events' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event
    parameter :tag_ids, 'array of existing tag ids', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes.merge("tag_ids" => [@tag1.id, @tag2.id])}.to_json }
    let(:authentication_token) { writer_token }

    # create two existing tags
    before do
      @tag1 = FactoryGirl.create(:tag)
      @tag2 = FactoryGirl.create(:tag)
    end

    #standard_request_options(: ,'CREATE (with tags_attributes (one existing, one new) as writer)', 201, nil, true)
    example 'CREATE (with existing tag_ids as writer) - 201', :document => true do
      tag_count = Tag.count
      request = do_request

      # expecting two 'taggings'

      # check response
      opts =
          {
              expected_status: :created,
              expected_method: :post,
              expected_response_content_type: 'application/json',
              document: document_media_requests
          }

      opts = acceptance_checks_shared(request, opts)

      opts.merge!({expected_json_path: 'data/taggings/1/tag_id', response_body_content: 'start_time_seconds'})
      acceptance_checks_json(opts)

      # only one tag should have been created, so new tag count should be one more than old tag count
      expect(tag_count).to eq(Tag.count)
    end
  end

  ################################
  # UPDATE
  ################################
  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request_options(:put, 'UPDATE (as writer)', :ok, {expected_json_path: 'data/taggings/0/audio_event_id'})
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request_options(:put, 'UPDATE (as writer with shallow path)', :ok, {expected_json_path: 'data/taggings/0/audio_event_id'})
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  put '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    parameter :start_time_seconds, 'start_time in seconds, has to be lower than end_time', scope: :audio_event, required: true
    parameter :end_time_seconds, 'end_time in seconds, has to be higher than start_time', scope: :audio_event
    parameter :low_frequency_hertz, 'low_frequency in hertz, has to be lower than high_frequency', scope: :audio_event, :required => true
    parameter :high_frequency_hertz, 'high_frequency in hertz, has to be higher than low frequency', scope: :audio_event
    parameter :is_reference, 'set to true if audio event is a reference', scope: :audio_event

    let(:raw_post) { {'audio_event' => post_attributes}.to_json }

    let(:authentication_token) { unconfirmed_token }

    standard_request_options(:put, 'UPDATE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  ################################
  # DELETE
  ################################

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { writer_token }
    standard_request_options(:delete, 'DELETE (as writer user)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'DELETE (as reader user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { other_token }
    standard_request_options(:delete, 'DELETE (as other user)', :forbidden, {expected_json_path: get_json_error_path(:permissions)})
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:delete, 'DELETE (as unconfirmed user)', :forbidden, {expected_json_path: get_json_error_path(:confirm)})
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'DELETE (as admin user)', :no_content, {expected_response_has_content: false, expected_response_content_type: nil})
  end

  delete '/audio_recordings/:audio_recording_id/audio_events/:id' do
    parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true
    parameter :id, 'Requested audio event id (in path/route)', required: true

    let(:authentication_token) { invalid_token }
    standard_request_options(:delete, 'DELETE (with invalid token)', :unauthorized, {expected_json_path: get_json_error_path(:sign_up)})
  end

  #####################
  # Filter
  #####################

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['5.2', '7', '100', '4']
            }
        },
        'projection' => {
            'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {
                                 expected_json_path: 'data/0/start_time_seconds',
                                 data_item_count: 1,
                                 regex_match: /"in"\:\[\"5.2\",\"7\",\"100\",\"[0-9]+\"\]/,
                                 response_body_content: "\"start_time_seconds\":",
                                 invalid_content: "\"project_ids\":[{\"id\":"
                             })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['5.2', '7', '100', '4']
            }
        },
        'projection' => {
            'include' => ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id']
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (as reader)', :ok,
                             {
                                 expected_json_path: 'data/0/start_time_seconds',
                                 data_item_count: 1,
                                 regex_match: [
                                     /"taggings":\[\{"id":\d+,"audio_event_id":\d+,/,
                                     /"created_at":"[^"]+"/,
                                     /"updated_at":"[^"]+"/,
                                     /"creator_id":\d+/,
                                     /"updater_id":null/
                                 ],
                                 response_body_content: "\"taggings\":[{\"",
                                 invalid_content: "\"taggings\":[\"",
                             })
  end


  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'in' => ['5.2', '7', '100', '4']
            }
        }
    }.to_json }
    standard_request_options(:post, 'FILTER (no projection, as reader)', :ok,
                             {
                                 expected_json_path: 'data/0/high_frequency_hertz',
                                 data_item_count: 1,
                                 regex_match: /"in"\:\[\"5.2\",\"7\",\"100\",\"[0-9]+\"\]/,
                                 response_body_content: "\"low_frequency_hertz\":400.0",
                                 invalid_content: "\"project_ids\":[{\"id\":"
                             })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { '{"filter":{"start_time_seconds":{"in":["5.2", "7", "100", "4"]}},"paging":{"items":10,"page":1},"sorting":{"orderBy":"durationSeconds","direction":"desc"}}' }
    standard_request_options(:post, 'FILTER (sort by custom field, as reader)', :ok,
                             {
                                 expected_json_path: 'meta/sorting/order_by',
                                 data_item_count: 1,
                                 regex_match: /"in"\:\[\"5.2\",\"7\",\"100\",\"[0-9]+\"\]/,
                                 response_body_content: ["\"low_frequency_hertz\":400.0", "\"order_by\":\"duration_seconds\""],
                                 invalid_content: "\"project_ids\":[{\"id\":"
                             })
  end

  post '/audio_events/filter' do
    let(:authentication_token) { reader_token }
    let(:raw_post) { {
        'filter' => {
            'start_time_seconds' => {
                'lt' => 2.5
            },
            'end_time_seconds' => {
                'gt' => 1
            }
        }
    }.to_json }

    before do
      #won't be included
      @ar_1 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 0, end_time_seconds: 1)
      #won't be included
      @ar_2 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 2.5, end_time_seconds: 5)
      #will be included
      @ar_3 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 0, end_time_seconds: 2)
      #will be included
      @ar_4 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 2, end_time_seconds: 4)
      #will be included
      @ar_5 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 1, end_time_seconds: 2.5)
      #will be included
      @ar_6 = FactoryGirl.create(:audio_event,
                                 audio_recording: writer_permission.project.sites[0].audio_recordings[0],
                                 start_time_seconds: 1.5, end_time_seconds: 2)
    end

    example 'FILTER (overlapping start and end filter)', document: true do
      do_request
      expect(status).to eq(200)

      json = JsonSpec::Helpers::parse_json(response_body)

      # should only return four
      expect(json['meta']['paging']['total']).to eq(4)


      sorted_data = json['data'].sort { |x, y| x['start_time_seconds'] <=> y['start_time_seconds'] }

      expect(sorted_data.size).to eq(4)
      expect(sorted_data[0]['id']).to eq(@ar_3.id)
      expect(sorted_data[1]['id']).to eq(@ar_5.id)
      expect(sorted_data[2]['id']).to eq(@ar_6.id)
      expect(sorted_data[3]['id']).to eq(@ar_4.id)
    end
  end

end