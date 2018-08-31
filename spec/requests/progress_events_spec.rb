require 'rails_helper'
require 'rspec/mocks'

describe "Progress Events" do

  create_entire_hierarchy

  let(:progress_event_attributes) {
    FactoryGirl.attributes_for(:progress_event, {dataset_item_id: dataset_item.id})
  }

  let(:progress_event_attributes_invalid_dataset_item_id) {
    attributes = progress_event_attributes
    attributes[:dataset_item_id] = 38921111
    attributes
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = "application/json"

    @create_progress_event_url = "/progress_events"
    @update_progress_event_url = "/progress_events/#{progress_event.id}"
  end

  describe 'Creating a progress event' do

    it 'does not allow a non-existent dataset item id' do
      params = {progress_event: progress_event_attributes_invalid_dataset_item_id}.to_json
      post @create_progress_event_url, params, @env
      expect(response).to have_http_status(422)
    end

  end

  describe 'Updating a progress event' do

    it 'does not allow a non-existent dataset item id' do
      params = {progress_event: progress_event_attributes_invalid_dataset_item_id}.to_json
      put @update_progress_event_url, params, @env
      expect(response).to have_http_status(422)
    end

  end

end



