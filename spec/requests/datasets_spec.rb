require 'rails_helper'
require 'rspec/mocks'

describe "Datasets" do

  create_entire_hierarchy

  let(:dataset_attributes) {
    FactoryGirl.attributes_for(:dataset)
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = "application/json"
  end

  describe 'Creating a dataset' do

    it 'does not allow a new dataset to be named default' do
      params = {dataset: dataset_attributes.merge({ name: 'default'})}.to_json
      post '/datasets', params, @env
      expect(response).to have_http_status(422)
      expect(Dataset.where(name: 'default').count).to eq(1)
    end

  end

  describe 'Updating a dataset' do

    it 'does not allow a dataset to be renamed to default' do
      params = {dataset: { name: 'default'}}.to_json
      put "/datasets/#{dataset.id}", params, @env
      expect(response).to have_http_status(422)
      expect(Dataset.where(name: 'default').count).to eq(1)
    end

  end

end



