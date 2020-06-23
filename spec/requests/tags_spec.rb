# frozen_string_literal: true

require 'rails_helper'
require 'rspec/mocks'

describe 'Tags' do
  create_entire_hierarchy

  def create(attributes = {})
    default_attributes = { text: 'test tag' }
    FactoryGirl.attributes_for(:tag, default_attributes.merge(attributes))
  end

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = 'application/json'

    @tag_url = '/tags'
    @tag_url_with_id = "/tags/#{tag.id}"
  end

  describe 'index' do
    it 'finds all (1) tag as admin' do
      get @tag_url, nil, @env
      expect(response).to have_http_status(200)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data'].count).to eq(1)
      expect(parsed_response['data'][0]['text']).to eq(tag['text'])
    end
  end

  describe 'filter' do
    it 'finds all (1) tag as admin' do
      get "#{@tag_url}/filter", nil, @env
      expect(response).to have_http_status(200)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data'].count).to eq(1)
      expect(parsed_response['data'][0]['text']).to eq(tag['text'])
    end
  end

  describe 'show' do
    it 'show tag as admin' do
      get @tag_url_with_id, nil, @env
      expect(response).to have_http_status(200)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['data'].to_json).to eq(tag.to_json)
    end
  end

  describe 'create' do
    it 'creates a tag' do
      post @tag_url, create.to_json, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(201)
      expect(parsed_response['data']['text']).to eq 'test tag'
    end

    it 'creates a taxonomic tag' do
      post @tag_url, create('is_taxanomic': true, 'type_of_tag': 'common_name').to_json, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(201)
      expect(parsed_response['data']['is_taxanomic']).to be true
      expect(parsed_response['data']['type_of_tag']).to eq 'common_name'
    end

    it 'creates a retired tag' do
      post @tag_url, create('retired': true).to_json, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(201)
      expect(parsed_response['data']['retired']).to be true
    end

    it 'creates a tag with notes' do
      post @tag_url, create('notes': { 'testing': 'value' }).to_json, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(201)
      expect(parsed_response['data']['notes']).to eq('testing' => 'value')
    end
  end
end
