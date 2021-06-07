# frozen_string_literal: true


require 'rspec/mocks'

describe 'Studies' do
  create_entire_hierarchy
  create_study_hierarchy

  let(:study_attributes) {
    FactoryBot.attributes_for(:study, { name: 'test study', dataset_id: dataset.id })
  }

  let(:update_study_attributes) {
    { name: 'updated study name' }
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = 'application/json'

    @study_url = '/studies'
    @study_url_with_id = "/studies/#{study.id}"
  end

  describe 'index,filter,show studies' do
    describe 'index' do
      it 'finds all (1) study as admin' do
        get @study_url, params: nil, headers: @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['name']).to eq(study['name'])
      end
    end

    describe 'filter' do
      it 'finds all (1) study as admin' do
        get "#{@study_url}/filter", params: nil, headers: @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['name']).to eq(study['name'])
      end
    end

    describe 'show' do
      it 'show study as admin' do
        get @study_url_with_id, params: nil, headers: @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].to_json).to eq(study.to_json)
      end
    end
  end

  describe 'create and update' do
    describe 'create study' do
      it 'creates a study' do
        post @study_url, params: study_attributes.to_json, headers: @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(201)
        expect(parsed_response['data']['dataset_id']).to eq(dataset.id)
      end
    end

    describe 'update study' do
      it 'updates a study' do
        params = { study: { name: 'modified study name' } }.to_json
        put @study_url_with_id, params: params, headers: @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        expect(parsed_response['data']['name']).to eq('modified study name')
      end
    end
  end

  describe 'delete' do
    it 'deletes a study and child responses' do
      delete @study_url_with_id, params: nil, headers: @env
      expect(response).to have_http_status(204)
      expect(Study.all.count).to eq(0)
      expect(Response.all.count).to eq(0)
    end
  end
end
