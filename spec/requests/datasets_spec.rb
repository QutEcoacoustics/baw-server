# frozen_string_literal: true


require 'rspec/mocks'

describe 'Datasets' do
  create_entire_hierarchy

  let(:dataset_attributes) {
    FactoryBot.attributes_for(:dataset)
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = 'application/json'
  end

  describe 'Creating a dataset' do
    it 'does not allow a new dataset to be named default' do
      params = { dataset: dataset_attributes.merge({ name: 'default' }) }.to_json
      post '/datasets', params: params, headers: @env
      expect(response).to have_http_status(422)
      expect(Dataset.where(name: 'default').count).to eq(1)
    end
  end

  describe 'Updating a dataset' do
    it 'does not allow a dataset to be renamed to default' do
      params = { dataset: { name: 'default' } }.to_json
      put "/datasets/#{dataset.id}", params: params, headers: @env
      expect(response).to have_http_status(422)
      expect(Dataset.where(name: 'default').count).to eq(1)
    end
  end

  describe 'filter' do
    it 'can do a projection' do
      post_body = {
        filter: {
          name: {
            eq: 'default'
          }
        },
        projection: {
          include: [:name]
        }
      }.to_json

      post '/datasets/filter', params: post_body, headers: @env
      expect(response).to have_http_status(200)
      #parsed_response = JSON.parse(response.body)
      #expect(parsed_response).to include('The default dataset')
    end
  end
end
