# frozen_string_literal: true

require 'rspec/mocks'

# Creates a simplified multipart/form-data message string
def form_data(attributes, boundary)
  message = "\r\n\r\n"
  attributes.each do |key, val|
    message += "--#{boundary}\r\n\r\n"
    message += "Content-Disposition: form-data; name=\"project[#{key}]\"\r\n\r\n"
    message += "#{val}\r\n"
  end
  message += "--#{boundary}--\r\n\r\n"
  message
end

form_boundary = 'simple_boundary'
form_content_type_string = "multipart/form-data; boundary=#{form_boundary}"

describe 'Projects' do
  prepare_users
  prepare_project
  prepare_permission_reader
  prepare_region

  let(:project_attributes) {
    attributes_for(:project)
  }

  let(:update_project_attributes) {
    { name: "#{project[:name]}modified" }
  }

  let(:form_project_data) {
    project_attributes = attributes_for(:project)
    form_data(project_attributes, form_boundary)
  }

  let(:form_project_data_update) {
    form_data(update_project_attributes, form_boundary)
  }

  before do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token

    @create_project_url = '/projects'
    @update_project_url = "/projects/#{project.id}"
  end

  # projects update/create actions expect payload from html form as well as json
  describe 'Creating a project' do
    it 'does allows multipart/form-data content-type' do
      @env['CONTENT_TYPE'] = form_content_type_string
      post @create_project_url, params: form_project_data, headers: @env
      # 302 because html requests are redirected to the newly created record
      expect(response).to have_http_status(:found)
    end

    it 'allows application/json content-type' do
      @env['CONTENT_TYPE'] = 'application/json'
      @env['ACCEPT'] = 'application/json'
      params = { project: project_attributes }.to_json
      post @create_project_url, params: params, headers: @env
      expect(response).to have_http_status(:created)
    end

    it 'rejects text/plain content-type with valid json multipart-form body' do
      @env['CONTENT_TYPE'] = 'text/plain'
      post @create_project_url, params: form_project_data, headers: @env
      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'rejects text/plain content-type with empty body' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = nil
      post @create_project_url, params: params, headers: @env
      expect(response).to have_http_status(:bad_request)
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
      expect(response).to have_http_status(:found)
    end

    it 'allows application/json content-type' do
      @env['CONTENT_TYPE'] = 'application/json'
      @env['ACCEPT'] = 'application/json'
      params = { project: update_project_attributes }.to_json
      put @update_project_url, params: params, headers: @env
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'API filtering' do
    create_entire_hierarchy

    example 'basically works' do
      body = {
        'filter' => {
          'id' => {
            'in' => [reader_permission.project.id]
          }
        },
        'projection' => {
          'include' => [:id, :name]
        }
      }
      post '/projects/filter', params: body, headers: api_request_headers(reader_token, send_body: true), as: :json

      expect(response).to have_http_status(:success)
      expect_at_least_one_item
      expect_has_projection({ include: ['id', 'name'] })
    end

    example 'filter partial match' do
      url = '/projects/filter?direction=desc&filter_name=a&filter_partial_match=partial_match_text&items=35&order_by=createdAt&page=1'
      get url, headers: api_request_headers(reader_token)
      expect(response).to have_http_status(:success)
      expect_zero_items
      expect_has_paging(
        page: 1,
        items: 35,
        current: 'http://localhost:3000/projects/filter?direction=desc&filter_name=a&filter_partial_match=partial_match_text&items=35&order_by=createdAt&page=1'
      )

      expect_has_sorting(order_by: 'created_at', direction: 'desc')
    end

    example 'filter with paging via GET' do
      # default items per page is 25
      create_list(:project, 29, creator: writer_user)

      get '/projects/filter?page=1&items=2', headers: api_request_headers(writer_token)

      expect(response).to have_http_status(:success)
      expect_number_of_items(2)
      expect_has_paging(page: 1, items: 2, total: Project.all.count)
    end
  end

  describe 'regions' do
    example 'api response can return region_ids' do
      expect(project.region_ids).to have_at_least(1).item

      get "/projects/#{project.id}", headers: api_request_headers(reader_token), as: :json

      expect_success
      expect(api_data).to match(hash_including({
        region_ids: project.region_ids
      }))
    end

    example 'api response can return empty array when no regions exist' do
      Region.all.delete_all
      get "/projects/#{project.id}", headers: api_request_headers(reader_token), as: :json

      expect_success
      expect(api_data).to match(hash_including({
        region_ids: []
      }))
    end
  end
end
