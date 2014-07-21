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
    @write_permission = FactoryGirl.create(:write_permission, creator: @user, user: @user)
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project, creator: @user, user: @user)

    @admin_user = FactoryGirl.create(:admin)
    @other_user = FactoryGirl.create(:user)
    @unconfirmed_user = FactoryGirl.create(:unconfirmed_user)
    @bookmark = FactoryGirl.create(
        :bookmark,
        creator: @user,
        audio_recording: @write_permission.project.sites.order(:id).first.audio_recordings.order(:id).first)
  end

  # prepare authentication_token for different users
  let(:admin_token) { "Token token=\"#{@admin_user.authentication_token}\"" }
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee, splat\"" }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:bookmark) }

  # List (#index)
  # ============

  # list all bookmarks
  # ------------------

  get '/bookmarks' do
    let(:authentication_token) { admin_token }
    standard_request('LIST for bookmarks (as admin)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { writer_token }
    standard_request('LIST for bookmarks (as writer)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { reader_token }
    standard_request('LIST for bookmarks (as reader)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { other_user_token }
    standard_request('LIST for bookmarks (as other user)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { unconfirmed_token }
    standard_request('LIST for bookmarks (as unconfirmed user)', 403, 'meta/error/details', true)
  end

  get '/bookmarks' do
    let(:authentication_token) { invalid_token }
    standard_request('LIST for bookmarks (with invaild token)', 403, 'meta/error/details', true)
  end

  # List bookmarks filtered by name
  # -------------------------------

  get '/bookmarks?name=the_expected_name' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name')
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name')
    }

    standard_request('LIST for user_account (as user)', 200, '0/offset_seconds', true, 'the_expected_name', 'the_unexpected_name')
  end

  # List bookmarks filtered by category
  # -----------------------------------

  get '/bookmarks?category=the_expected_category' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category')
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category')
    }

    standard_request('LIST for user_account (as user)', 200, '0/offset_seconds', true, 'the_expected_category', 'the_unexpected_category')
  end

  # Create (#create)
  # ================

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: post_attributes}.to_json }
    let(:authentication_token) { user_token }

    standard_request('CREATE (as user)', 201, 'offset_seconds', true)
  end

  # New Item (#new)
  # ===============

  get '/bookmarks/new' do
    let(:authentication_token) { user_token }
    standard_request('NEW for user_account (as user)', 200, '0/offset_seconds', true)
  end

  # Existing Item (#show)
  # ================

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    standard_request('SHOW (as user)', 200, 'offset_seconds', true)
  end

  # Update (#update)
  # ================

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    standard_request('UPDATE (as user)', 200, 'offset_seconds', true)
  end

  # Delete (#destroy)
  # ================

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    standard_request('DELETE (as user)', 200, 'offset_seconds', true)
  end

end