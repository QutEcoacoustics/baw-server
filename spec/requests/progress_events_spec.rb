require 'rails_helper'
require 'rspec/mocks'

# create the url for create_by_dataset_item_params based on the dataset item
# @param dataset_item Object to use for the dataset item params
# @param params Hash any values to use instead of the dataset_item's values
def create_by_dataset_item_params_path (dataset_item, params = {})
  valid_params = [:dataset_id, :audio_recording_id, :start_time_seconds, :end_time_seconds]
  params = values_to_string(dataset_item.attributes.symbolize_keys.slice(*valid_params).merge(params.symbolize_keys.slice(*valid_params)))
  url = "/datasets/#{params[:dataset_id]}/progress_events/audio_recordings/#{params[:audio_recording_id]}/start/#{params[:start_time_seconds]}/end/#{params[:end_time_seconds]}"
  { path: url, params: params }
end

describe "Progress Events" do

  create_entire_hierarchy

  let(:progress_event_attributes) {
    FactoryGirl.attributes_for(:progress_event, {dataset_item_id: dataset_item.id})
  }

  let!(:another_dataset_item) {
    another_dataset_item = FactoryGirl.create(:dataset_item,
                                      creator: writer_user,
                                      dataset: dataset,
                                      audio_recording: audio_recording,
                                      start_time_seconds: 23,
                                      end_time_seconds: 33,
                                      order: 55.5)
    another_dataset_item
  }

  let(:progress_event_attributes_invalid_dataset_item_id) {
    attributes = progress_event_attributes
    attributes[:dataset_item_id] = 38921111
    attributes
  }

  let(:progress_event_attributes_2) {
    attributes = progress_event_attributes.dup
    attributes.delete(:dataset_item_id)
    attributes
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = reader_token
    @env['CONTENT_TYPE'] = "application/json"

    @create_progress_event_url = "/progress_events"
    @update_progress_event_url = "/progress_events/#{progress_event.id}"
  end

  # converts values of a hash to string
  # not recursive: does not work on nested hashes
  def values_to_string hash
    hash.each { |key,val| hash[key] = val.to_s }
    hash
  end

  describe 'Creating a progress event' do

    it 'creates a progress event' do
      params = {progress_event: progress_event_attributes}.to_json
      post @create_progress_event_url, params, @env
      expect(response).to have_http_status(201)
    end


    it 'does not allow a non-existent dataset item id' do
      params = {progress_event: progress_event_attributes_invalid_dataset_item_id}.to_json
      post @create_progress_event_url, params, @env
      expect(response).to have_http_status(422)
    end

  end

  describe 'Updating a progress event' do

    it 'does not allow a non-existent dataset item id (admin user)' do
      @env['HTTP_AUTHORIZATION'] = admin_token
      params = {progress_event: progress_event_attributes_invalid_dataset_item_id}.to_json
      put @update_progress_event_url, params, @env
      expect(response).to have_http_status(422)
    end

    it 'does not allow a non-existent dataset item id (owner user)' do
      @env['HTTP_AUTHORIZATION'] = owner_token
      params = {progress_event: progress_event_attributes_invalid_dataset_item_id}.to_json
      put @update_progress_event_url, params, @env
      expect(response).to have_http_status(403)
    end

  end

  describe 'Creating a progress event by dataset item parameters' do

    let! (:num_progress_events_before) { ProgressEvent.count }
    let! (:num_dataset_items_before) { DatasetItem.count }

    # checks if the number of progress events and dataset items after the request is what is expected
    # @param expect_new_progress_event Boolean should 1 new progress event have been added?
    # @param expect_new_dataset_item Boolean should 1 new dataset_item have been added?
    def check_counts (expect_new_progress_event = false, expect_new_dataset_item = false)

      num_expected_progress_events = num_progress_events_before
      if expect_new_progress_event
        num_expected_progress_events += 1
      end
      num_expected_dataset_items = num_dataset_items_before
      if expect_new_dataset_item
        num_expected_dataset_items += 1
      end

      expect(ProgressEvent.count).to eq(num_expected_progress_events)
      expect(DatasetItem.count).to eq(num_expected_dataset_items)

    end

    describe 'using parameters of existing dataset item' do

      let (:valid_url) {
        create_by_dataset_item_params_path(another_dataset_item)
      }

      it 'Creates a progress event when user has access to audio recording' do
        params = {progress_event: progress_event_attributes_2}.to_json
        post valid_url[:path], params, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(201)
        expect(parsed_response['data']['dataset_item_id']).to eq(another_dataset_item.id)
        check_counts true, false
      end

      it 'responds with :forbidden if user does not have access to audio recording' do
        @env['HTTP_AUTHORIZATION'] = no_access_token
        params = {progress_event: progress_event_attributes_2}.to_json
        post valid_url[:path], params, @env
        expect(response).to have_http_status(:forbidden)
        check_counts
      end

    end

    it 'Returns 422 when parameters do not match existing dataset item for non-default dataset' do
      url = create_by_dataset_item_params_path(another_dataset_item, {'end_time_seconds' => another_dataset_item.end_time_seconds + 1})
      params = {progress_event: progress_event_attributes_2}.to_json
      post url[:path], params, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(422)
      expect(values_to_string(parsed_response['meta']['error']['info']).symbolize_keys).to eq(url[:params])
      check_counts
    end

    describe 'using parameters of non-existing dataset item in default dataset' do

      let (:url) {
        create_by_dataset_item_params_path(default_dataset_item, {'start_time_seconds' => default_dataset_item.start_time_seconds + 100, 'end_time_seconds' => default_dataset_item.end_time_seconds + 100})
      }

      it 'Creates a dataset item and progress event for the default dataset' do
        params = {progress_event: progress_event_attributes_2}.to_json
        post url[:path], params, @env
        expect(response).to have_http_status(201)
        parsed_response = JSON.parse(response.body)
        created_dataset_item = DatasetItem.find(parsed_response['data']['dataset_item_id'])
        # check that the associated dataset item has the same attributes as what we specified in the request
        created_dataset_item_attributes = values_to_string(created_dataset_item.attributes.symbolize_keys.slice(*url[:params].keys))
        expect(created_dataset_item_attributes).to eq(url[:params])
        expect(created_dataset_item.dataset_id).to eq(1)
        check_counts true, true
      end

      it 'responds with :forbidden if user does not have access to audio recording' do
        @env['HTTP_AUTHORIZATION'] = no_access_token
        params = {progress_event: progress_event_attributes_2}.to_json
        post url[:path], params, @env
        expect(response).to have_http_status(:forbidden)
        parsed_response = JSON.parse(response.body)
        check_counts
      end

    end

    it 'Responds with 422 if dataset item params for default dataset are invalid: same start and end time' do
      url = create_by_dataset_item_params_path(default_dataset_item, {'start_time_seconds' => '123', 'end_time_seconds' => '123'})
      params = {progress_event: progress_event_attributes_2}.to_json
      post url[:path], params, @env
      num_progress_events_after = ProgressEvent.count
      num_dataset_items_after = DatasetItem.count
      expect(response).to have_http_status(422)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['info']['end_time_seconds']).to eq(['must be greater than 123.0'])
      check_counts
    end

  end

end
