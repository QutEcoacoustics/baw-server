require 'rails_helper'
require 'rspec/mocks'

describe "Dataset Items" do

  create_entire_hierarchy

  let(:dataset_item_attributes) {
    FactoryGirl.attributes_for(:dataset_item, {audio_recording_id: audio_recording.id})
  }

  let(:update_dataset_item_attributes) {
    {end_time_seconds: (dataset_item.end_time_seconds + 5) }
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token

    @create_dataset_item_url = "/datasets/" + dataset.id.to_s + "/items"
    @update_dataset_item_url = "/datasets/" + dataset_item.dataset_id.to_s + "/items/" + dataset_item.id.to_s
  end

  describe 'Creating a dataset item' do

    it 'does not allow text/plain content-type' do
      @env['CONTENT_TYPE'] = "text/plain"
      params = {dataset_item: dataset_item_attributes}.to_json
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'does not allow application/x-www-form-urlencoded content-type with json data' do
      # use default form content type
      params = {dataset_item: dataset_item_attributes}.to_json
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'allows application/json content-type with json data' do
      @env['CONTENT_TYPE'] = "application/json"
      params = {dataset_item: dataset_item_attributes}.to_json
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(201)
    end

    it 'allows application/json content-type with unnested json data' do
      @env['CONTENT_TYPE'] = "application/json"
      params = dataset_item_attributes.to_json
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(201)
    end

    # can't catch json content with multipart/form-data content type
    # because the middleware errors when trying to parse it

    it 'does not allow empty body (nil, json)' do
      @env['CONTENT_TYPE'] = "application/json"
      params = nil
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
    end

    it 'does not allow empty body (empty string, json)' do
      @env['CONTENT_TYPE'] = "application/json"
      params = ""
      post @create_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
      expect(response.content_type).to eq "application/json"
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['links']).to eq({"New Resource"=>"/datasets/2/items/new"})
    end

  end


  describe 'Updating a dataset item' do

    it 'does not allow text/plain content-type' do
      @env['CONTENT_TYPE'] = "text/plain"
      params = {dataset_item: update_dataset_item_attributes}.to_json

      put @update_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'does not allow application/x-www-form-urlencoded with json body' do
      # use default form content type
      params = {dataset_item: update_dataset_item_attributes}.to_json

      put @update_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'allows application/json content-type with json body' do
      @env['CONTENT_TYPE'] = "application/json"
      params = {dataset_item: update_dataset_item_attributes}.to_json

      put @update_dataset_item_url, params, @env
      expect(response).to have_http_status(200)
    end

  end

end



