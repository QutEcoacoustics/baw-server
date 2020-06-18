# frozen_string_literal: true

require 'rails_helper'
require 'rspec/mocks'

describe 'Dataset Items' do
  create_entire_hierarchy

  let(:dataset_item_attributes) {
    FactoryBot.attributes_for(:dataset_item, { audio_recording_id: audio_recording.id })
  }

  let(:update_dataset_item_attributes) {
    { end_time_seconds: (dataset_item.end_time_seconds + 5) }
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token

    @direct_dataset_item_url = "/datasets/#{dataset.id}/items" #@direct_dataset_item_url
    @nested_dataset_item_url = "/datasets/#{dataset_item.dataset_id}/items/#{dataset_item.id}" #@nested_dataset_item_url
  end

  describe 'Creating a dataset item' do
    it 'does not allow text/plain content-type' do
      @env['CONTENT_TYPE'] = 'text/plain'
      params = { dataset_item: dataset_item_attributes }.to_json
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'does not allow application/x-www-form-urlencoded content-type with json data' do
      # use default form content type
      params = { dataset_item: dataset_item_attributes }.to_json
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'allows application/json content-type with json data' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = { dataset_item: dataset_item_attributes }.to_json
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(201)
    end

    it 'allows application/json content-type with unnested json data' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = dataset_item_attributes.to_json
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(201)
    end

    # can't catch json content with multipart/form-data content type
    # because the middleware errors when trying to parse it

    it 'does not allow empty body (nil, json)' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = nil
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['links']).to eq({ 'New Resource' => '/datasets/2/items/new' })
    end

    it 'does not allow empty body (empty string, json)' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = ''
      post @direct_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
      expect(response.content_type).to eq 'application/json'
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['links']).to eq({ 'New Resource' => '/datasets/2/items/new' })
    end
  end

  describe 'Updating a dataset item' do
    it 'does not allow text/plain content-type' do
      @env['CONTENT_TYPE'] = 'text/plain'
      params = { dataset_item: update_dataset_item_attributes }.to_json

      put @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'does not allow application/x-www-form-urlencoded with json body' do
      # use default form content type
      params = { dataset_item: update_dataset_item_attributes }.to_json

      put @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(415)
    end

    it 'allows application/json content-type with json body' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = { dataset_item: update_dataset_item_attributes }.to_json

      put @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(200)
    end

    it 'does not allow empty body (nil, json)' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = nil
      put @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['links']).to eq({ 'New Resource' => '/datasets/2/items/new' })
    end

    it 'does not allow empty body (empty string, json)' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = ''
      put @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(400)
      expect(response.content_type).to eq 'application/json'
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['meta']['error']['links']).to eq({ 'New Resource' => '/datasets/2/items/new' })
    end
  end

  describe 'delete' do
    it 'deletes dataset item and any children' do
      dataset_item_count = DatasetItem.all.count
      progress_event_count = ProgressEvent.all.count
      response_count = Response.all.count
      expected_progress_event_count = progress_event_count - ProgressEvent.where(dataset_item_id: dataset_item.id).count
      expected_response_count = response_count - Response.where(dataset_item_id: dataset_item.id).count

      @env['CONTENT_TYPE'] = 'application/json'
      params = ''
      delete @nested_dataset_item_url, params, @env
      expect(response).to have_http_status(204)
      #parsed_response = JSON.parse(response.body)

      # ensure dataset has been deleted
      expect(DatasetItem.all.count).to eq(dataset_item_count - 1)
      # ensure children are deleted
      expect(ProgressEvent.all.count).to eq(expected_progress_event_count)
      expect(Response.all.count).to eq(expected_response_count)
    end
  end

  describe 'filter' do
    it 'does not allow arbitrary string in sort column' do
      @env['CONTENT_TYPE'] = 'application/json'
      params = {
        sorting: {
          order_by: '; select * from projects',
          direction: 'desc'
        }
      }.to_json

      post '/dataset_items/filter', params, @env
      expect(response).to have_http_status(400)
    end
  end

  describe 'list next for me' do
    # filters sorts and pages an array of dataset items
    # to mirror what should be returned by the api, so that it can be compared
    # @param items, array of created dataset items
    # @user User object. The sort order is dependent on the user
    # @page int which page to get
    # @limit int how many items per page
    def filter_and_sort_for_comparison(items, user, page = nil, limit = nil)
      # if limit is not supplied, default is 25
      limit ||= 25
      page ||= 1

      # filter only dataset items with the right dataset id
      filtered = items.select { |item| item[:dataset_item][:dataset_id] == dataset.id }

      # sort by number of views, number of own views, id
      sorted = filtered.sort_by { |item|
        [
          # number of progress events of type "viewed"
          (item[:progress_events].select { |progress_event| progress_event.activity == 'viewed' }).size,
          # number of progress events of type "viewed" created by the user
          (item[:progress_events].select { |progress_event|
            progress_event.activity == 'viewed' && progress_event.creator_id == user.id
          }).size,
          # order
          item[:dataset_item][:order],
          # dataset item id
          item[:dataset_item][:id]
        ]
      }

      # get the ids in the order we expect them back
      sorted_ids = sorted.map { |item| item[:dataset_item][:id] }

      from_index = (page - 1) * limit
      to_index = from_index + limit - 1

      from_index = [from_index, sorted_ids.count].min
      to_index = [to_index, sorted_ids.count].min
      sorted_ids = sorted_ids[from_index..to_index]

      sorted_ids
    end

    before(:each) do
      @env['CONTENT_TYPE'] = 'application/json'
      @dataset_item_filter_url = "/datasets/#{dataset_item.dataset_id}/dataset_items/filter"
      @dataset_item_next_for_me_url = "/datasets/#{dataset_item.dataset_id}/dataset_items/next_for_me"
    end

    create_many_dataset_items

    let(:raw_post) {
      {
        sorting: {
          order_by: :priority
        }
      }.to_json
    }

    it 'gets all dataset items' do
      many_dataset_items_some_with_events
      post @dataset_item_filter_url, raw_post, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(200)
    end

    it 'orders dataset items by least viewed first (admin user)' do
      # create an array that has the stuff from create_entire_hierarchy as well as the stuff created above
      all_dataset_items = many_dataset_items_some_with_events
      sorted_ids = filter_and_sort_for_comparison(all_dataset_items, admin_user, 1, 25)
      get @dataset_item_next_for_me_url, nil, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      ids = parsed_response['data'].map { |item| item['id'] }
      expect(ids).to eq(sorted_ids)
    end

    it 'orders dataset items by least viewed first (writer user)' do
      @env['HTTP_AUTHORIZATION'] = writer_token

      # create an array that has the stuff from create_entire_hierarchy as well as the stuff created above
      all_dataset_items = many_dataset_items_some_with_events
      sorted_ids = filter_and_sort_for_comparison(all_dataset_items, writer_user, 1, 25)
      get @dataset_item_next_for_me_url, nil, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      ids = parsed_response['data'].map { |item| item['id'] }
      expect(ids).to eq(sorted_ids)
    end

    it 'orders dataset items by least viewed first (reader user)' do
      @env['HTTP_AUTHORIZATION'] = reader_token

      # create an array that has the stuff from create_entire_hierarchy as well as the stuff created above
      all_dataset_items = many_dataset_items_some_with_events
      sorted_ids = filter_and_sort_for_comparison(all_dataset_items, reader_user, 1, 25)
      get @dataset_item_next_for_me_url, nil, @env
      parsed_response = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      ids = parsed_response['data'].map { |item| item['id'] }
      expect(ids).to eq(sorted_ids)
    end

    describe 'batch check paging' do
      # for each user, check different combinations of page number and limit/items
      # to make sure that the correct items are returned for that user, and that the paging
      # metadata is also correct

      let(:user_tokens) { [admin_token, writer_token, reader_token] }
      let(:users) { [admin_user, writer_user, reader_user] }
      users_description = ['admin', 'writer', 'reader']
      pages = [1, 20, nil]
      limits = [1, 7, 40, nil]

      combos = (0..(users_description.length - 1)).to_a
                                                  .product(pages, limits).map { |c| { u: c[0], page: c[1], limit: c[2] } }

      combos.each do |combo|
        u = combo[:u]
        page = combo[:page]
        limit = combo[:limit]

        it "orders items correctly for #{users_description[u]} page #{page} limit #{limit} " do
          @env['HTTP_AUTHORIZATION'] = user_tokens[u]

          # create an array that has the stuff from create_entire_hierarchy as well as the stuff created above
          # this runs on every iteration ... so it's slow!
          all_dataset_items = many_dataset_items_some_with_events
          sorted_ids = filter_and_sort_for_comparison(all_dataset_items, users[u], page, limit)
          qsp = {}
          qsp[:page] = page if page
          qsp[:items] = limit if limit
          get @dataset_item_next_for_me_url, qsp, @env
          parsed_response = JSON.parse(response.body)

          expect(response).to have_http_status(200)
          ids = parsed_response['data'].map { |item| item['id'] }
          expect(ids).to eq(sorted_ids)

          expected_page = page || 1
          expected_items = limit || 25
          # all items this user should see, but with no limit
          expected_total = filter_and_sort_for_comparison(all_dataset_items, users[u], 1, 10_000).count
          expected_max_page = (expected_total.to_f / expected_items).ceil

          paging_response = parsed_response.dig('meta', 'paging')

          expect(paging_response).to be_a(Hash)

          if paging_response
            paging_numbers = paging_response.slice('page', 'items', 'total', 'max_page').symbolize_keys
            expected_paging_numbers = { page: expected_page, items: expected_items, total: expected_total, max_page: expected_max_page }
            paging_numbers.should == expected_paging_numbers

            # next, previous and current pages are limited to between 1 and max_page (inclusive)
            # if next or previous ends up being the same as current after this limiting, it is not included
            if expected_page < expected_max_page
              expect(paging_response['next']).to be_a(String)
            else
              expect(paging_response['next']).to be(nil)
            end

            # if expected_page were > expected_max_page, the link to current and previous
            # would both be a link to the max page, so prev would not be included
            if expected_page > 1 && expected_page <= expected_max_page
              expect(paging_response['previous']).to be_a(String)
            else
              expect(paging_response['previous']).to be(nil)
            end

          end
        end
      end
    end
  end
end
