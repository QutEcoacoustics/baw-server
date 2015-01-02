require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Bookmarks' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    @user = FactoryGirl.create(:user)
    @admin_user = FactoryGirl.create(:admin)
    @other_user = FactoryGirl.create(:user)
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)

    @write_permission = FactoryGirl.create(:write_permission, creator: @user)
    @writer_user = @write_permission.user
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project, creator: @user)
    @reader_user = @read_permission.user
    FactoryGirl.create(:read_permission, creator: @admin_user, project: @write_permission.project, user: @user)

    @bookmark = FactoryGirl.create(
        :bookmark,
        creator: @user,
        audio_recording: @write_permission.project.sites.order(:id).first.audio_recordings.order(:id).first)

    # only two bookmarks, both created by @user
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@writer_user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@reader_user.authentication_token}\"" }
  let(:user_token) { "Token token=\"#{@user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  let(:post_attributes) { FactoryGirl.attributes_for(:bookmark) }

  # List (#index)
  # ============

  # list all bookmarks
  # ------------------

  get '/bookmarks' do
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'LIST (as admin)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  get '/bookmarks' do
    let(:authentication_token) { writer_token }
    standard_request_options(:get, 'LIST (as writer)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  get '/bookmarks' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'LIST (as reader)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  get '/bookmarks' do
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'LIST (as user)', :ok, {expected_json_path: 'data/0/offset_seconds', data_item_count: 1})
  end

  get '/bookmarks' do
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'LIST (as other user)', :ok, {response_body_content: '200', data_item_count: 0})
  end

  get '/bookmarks' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'LIST (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/bookmarks' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'LIST (with invaild token)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # List bookmarks filtered by name
  # -------------------------------

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name', creator: @reader_user)
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name', creator: @reader_user)
    }

    standard_request_options(:get, 'LIST matching name (as reader)', :ok, {
        expected_json_path: 'data/0/offset_seconds',
        response_body_content: 'the_expected_name',
        invalid_content: 'the_unexpected_name',
        data_item_count: 1
    })
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name', creator: @user)
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name', creator: @user)
    }

    standard_request_options(:get, 'LIST matching name (as user)', :ok, {
        expected_json_path: 'data/0/offset_seconds',
        response_body_content: 'the_expected_name',
        invalid_content: 'the_unexpected_name',
        data_item_count: 1
    })
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { unconfirmed_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name', creator: @unconfirmed_user)
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name', creator: @unconfirmed_user)
    }

    standard_request_options(:get, 'LIST matching name (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/bookmarks?filter_name=the_expected_name' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name', creator: @user)
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name', creator: @user)
    }

    standard_request_options(:get, 'LIST matching name (with invalid token)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # List bookmarks filtered by category
  # -----------------------------------

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category', creator: @reader_user)
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category', creator: @reader_user)
    }

    standard_request_options(:get, 'LIST matching category (as reader)', :ok, {
        expected_json_path: 'data/0/offset_seconds',
        response_body_content: 'the_expected_category',
        invalid_content: 'the_unexpected_category',
        data_item_count: 1
    })
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category', creator: @user)
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category', creator: @user)
    }

    standard_request_options(:get, 'LIST matching category (as user)', :ok, {
        expected_json_path: 'data/0/offset_seconds',
        response_body_content: 'the_expected_category',
        invalid_content: 'the_unexpected_category',
        data_item_count: 1
    })
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { unconfirmed_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category', creator: @unconfirmed_user)
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category', creator: @unconfirmed_user)
    }

    standard_request_options(:get, 'LIST matching category (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/bookmarks?filter_category=the_expected_category' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category', creator: @user)
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category', creator: @user)
    }

    standard_request_options(:get, 'LIST matching category (with invalid token)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # Create (#create)
  # ================

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @admin_user)}.to_json }
    let(:authentication_token) { admin_token }

    standard_request_options(:post, 'CREATE (as admin)', :created, {expected_json_path: 'data/offset_seconds'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @writer_user)}.to_json }
    let(:authentication_token) { writer_token }

    standard_request_options(:post, 'CREATE (as writer)', :created, {expected_json_path: 'data/offset_seconds'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @reader_user)}.to_json }
    let(:authentication_token) { reader_token }

    standard_request_options(:post, 'CREATE (as reader)', :created, {expected_json_path: 'data/offset_seconds'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @user)}.to_json }
    let(:authentication_token) { user_token }

    standard_request_options(:post, 'CREATE (as user)', :created, {expected_json_path: 'data/offset_seconds'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @other_user)}.to_json }
    let(:authentication_token) { other_user_token }

    # fails because other user does not have any access to @bookmark.audio_recording_id
    standard_request_options(:post, 'CREATE (as other user)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @unconfirmed_user)}.to_json }
    let(:authentication_token) { unconfirmed_token }

    standard_request_options(:post, 'CREATE (as unconfirmed user)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @user)}.to_json }
    let(:authentication_token) { invalid_token }

    standard_request_options(:post, 'CREATE (with invalid token)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # New Item (#new)
  # ===============

  get '/bookmarks/new' do
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'NEW (as reader)', :ok, {expected_json_path: 'data/offset_seconds'})
  end

  get '/bookmarks/new' do
    let(:authentication_token) { user_token }
    standard_request_options(:get, 'NEW (as user)', :ok, {expected_json_path: 'data/offset_seconds'})
  end

  get '/bookmarks/new' do
    let(:authentication_token) { other_user_token }
    standard_request_options(:get, 'NEW (as reader)', :ok, {expected_json_path: 'data/offset_seconds'})
  end

  get '/bookmarks/new' do
    let(:authentication_token) { unconfirmed_token }
    standard_request_options(:get, 'NEW (as reader)', :forbidden, {expected_json_path: 'meta/error/links/confirm your account'})
  end

  get '/bookmarks/new' do
    let(:authentication_token) { invalid_token }
    standard_request_options(:get, 'NEW (as reader)', :unauthorized, {expected_json_path: 'meta/error/links/sign in'})
  end

  # Existing Item (#show)
  # ================

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    standard_request_options(:get, 'SHOW (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    standard_request_options(:get, 'SHOW (as user)', :ok, {expected_json_path: 'data/offset_seconds'})
  end

  # Update (#update)
  # ================

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    let(:raw_post) { {'bookmark' => post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    let(:raw_post) { {'bookmark' => post_attributes}.to_json }
    standard_request_options(:put, 'UPDATE (as user)', :ok, {expected_json_path: 'data/category'})
  end

  # Delete (#destroy)
  # ================

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    standard_request_options(:delete, 'DESTROY (as reader)', :forbidden, {expected_json_path: 'meta/error/links/request permissions'})
  end

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    standard_request_options(:delete, 'DESTROY (as user)', :no_content, {expected_response_has_content:false, expected_response_content_type: nil})
  end

  # Filter (#filter)
  # ================

  post '/bookmarks/filter' do
    let(:raw_post) { {
        filter: {
            and: {
                offset_seconds: {
                    less_than: 123456
                },
                description: {
                    contains: 'description'
                }
            }
        }
    }.to_json }
    let(:authentication_token) { user_token }
    standard_request_options(:post, 'FILTER (as reader)', :ok, {expected_json_path: 'data/0/category', data_item_count: 1})
  end

end