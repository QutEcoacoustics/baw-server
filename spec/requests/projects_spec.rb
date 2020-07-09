# frozen_string_literal: true

require 'rails_helper'
require 'rspec/mocks'

# Creates a simplified multipart/form-data message string
def form_data(attributes, boundary)
  message = "\r\n\r\n"
  attributes.each do |key, val|
    message += '--' + boundary + "\r\n\r\n"
    message += 'Content-Disposition: form-data; name="project[' + key.to_s + "]\"\r\n\r\n"
    message += val.to_s + "\r\n"
  end
  message += '--' + boundary + "--\r\n\r\n"
  message
end

form_boundary = 'simple_boundary'
form_content_type_string = 'multipart/form-data; boundary=' + form_boundary

describe 'Projects' do
  prepare_users
  prepare_project

  let(:project_attributes) {
    FactoryBot.attributes_for(:project)
  }

  let(:update_project_attributes) {
    { name: (project[:name] + 'modified') }
  }

  let(:form_project_data) {
    project_attributes = FactoryBot.attributes_for(:project)
    form_data(project_attributes, form_boundary)
  }

  let(:form_project_data_update) {
    form_data(update_project_attributes, form_boundary)
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token

    @create_project_url = '/projects'
    @update_project_url = '/projects/' + project.id.to_s
  end

  # projects update/create actions expect payload from html form as well as json
  describe 'Creating a project' do
    it 'does allows multipart/form-data content-type' do
      @env['CONTENT_TYPE'] = form_content_type_string
      post @create_project_url, params: form_project_data, headers: @env
      # 302 because html requests are redirected to the newly created record
      expect(response).to have_http_status(302)
    end

    it 'allows application/json content-type' do
      @env['CONTENT_TYPE'] = 'application/json'
      @env['ACCEPT'] = 'application/json'
      params = { project: project_attributes }.to_json
      post @create_project_url, params: params, headers: @env
      expect(response).to have_http_status(201)
    end

    it 'rejects text/plain content-type with valid json multipart-form body' do
      @env['CONTENT_TYPE'] = 'text/plain'
      post @create_project_url, params: form_project_data, headers: @env
      expect(response).to have_http_status(415)
    end

    it 'rejects text/plain content-type with empty body' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = nil
      post @create_project_url, params: params, headers: @env
      expect(response).to have_http_status(400)
      # projects#create does not have json as default response format,
      # so, we get a html response
      # check that the link to new is in the error message
      expect(response.body).to match 'projects/new'
    end

    # can't test empty body with multipart/form-data content type
    # because middleware errors when trying to parse it
  end

  describe 'Updating a project' do
    it 'does allows multipart/form-data content-type' do
      @env['CONTENT_TYPE'] = form_content_type_string
      put @update_project_url, params: form_project_data_update, headers: @env
      expect(response).to have_http_status(302)
    end

    it 'allows application/json content-type' do
      @env['CONTENT_TYPE'] = 'application/json'
      @env['ACCEPT'] = 'application/json'
      params = { project: update_project_attributes }.to_json
      put @update_project_url, params: params, headers: @env
      expect(response).to have_http_status(200)
    end
  end
end
