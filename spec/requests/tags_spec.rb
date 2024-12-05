# frozen_string_literal: true

require 'rspec/mocks'

describe 'Tags' do
  create_entire_hierarchy

  def create(attributes = {})
    default_attributes = { text: 'test tag' }
    attributes_for(:tag, default_attributes.merge(attributes))
  end

  before do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = 'application/json'

    @tag_url = '/tags'
    @tag_url_with_id = "/tags/#{tag.id}"
  end

  describe 'index' do
    it 'finds all (1) tag as admin' do
      get @tag_url, params: nil, headers: @env
      expect(response).to have_http_status(:ok)
      parsed_response = response.parsed_body
      expect(parsed_response['data'].count).to eq(1)
      expect(parsed_response['data'][0]['text']).to eq(tag['text'])
    end
  end

  describe 'filter' do
    it 'finds all (1) tag as admin' do
      get "#{@tag_url}/filter", params: nil, headers: @env
      expect(response).to have_http_status(:ok)
      parsed_response = response.parsed_body
      expect(parsed_response['data'].count).to eq(1)
      expect(parsed_response['data'][0]['text']).to eq(tag['text'])
    end
  end

  describe 'show' do
    it 'show tag as admin' do
      get @tag_url_with_id, params: nil, headers: @env
      expect(response).to have_http_status(:ok)
      parsed_response = response.parsed_body
      expect(parsed_response['data']).to match(tag.as_json)
    end
  end

  describe 'create' do
    it 'creates a tag' do
      post @tag_url, params: create.to_json, headers: @env
      parsed_response = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(parsed_response['data']['text']).to eq 'test tag'
    end

    it 'creates a taxonomic tag' do
      post @tag_url, params: create(is_taxonomic: true, type_of_tag: 'common_name').to_json, headers: @env
      parsed_response = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(parsed_response['data']['is_taxonomic']).to be true
      expect(parsed_response['data']['type_of_tag']).to eq 'common_name'
    end

    it 'creates a retired tag' do
      post @tag_url, params: create(retired: true).to_json, headers: @env
      parsed_response = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(parsed_response['data']['retired']).to be true
    end

    it 'creates a tag with notes' do
      post @tag_url, params: create(notes: { testing: 'value' }).to_json, headers: @env
      parsed_response = response.parsed_body
      expect(response).to have_http_status(:created)
      expect(parsed_response['data']['notes']).to eq('testing' => 'value')
    end
  end
end
