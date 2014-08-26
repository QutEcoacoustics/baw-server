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

    @write_permission = FactoryGirl.create(:write_permission, creator: @user)
    @writer_user = @write_permission.user
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project, creator: @user)
    @reader_user = @read_permission.user
    FactoryGirl.create(:read_permission, creator: @user, project: @write_permission.project, user: @user)

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
  let(:user_token) { "Token token=\"#{@user.authentication_token}\"" }
  let(:other_user_token) { "Token token=\"#{@other_user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{@unconfirmed_user.authentication_token}\"" }
  let(:invalid_token) { "Token token=\"weeeeeeeee0123456789splat\"" }

  # List (#index)
  # ============

  # list all bookmarks
  # ------------------

  get '/bookmarks' do
    let(:authentication_token) { admin_token }
    standard_request('LIST (as admin)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { writer_token }
    standard_request('LIST (as writer)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { reader_token }
    standard_request('LIST (as reader)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { user_token }
    standard_request('LIST (as user)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { other_user_token }
    standard_request('LIST (as other user)', 200, 'data/0/offset_seconds')
  end

  get '/bookmarks' do
    let(:authentication_token) { unconfirmed_token }
    standard_request('LIST (as unconfirmed user)', 403, 'meta/error/links/confirm your account', true)
  end

  get '/bookmarks' do
    let(:authentication_token) { invalid_token }
    standard_request('LIST (with invaild token)', 401, 'meta/error/links/sign in', true)
  end

  # List bookmarks filtered by name
  # -------------------------------

  get '/bookmarks?name=the_expected_name' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name')
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name')
    }

    standard_request('LIST matching name (as reader)', 200, 'data/0/offset_seconds', true, 'the_expected_name', 'the_unexpected_name')
  end

  get '/bookmarks?name=the_expected_name' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name')
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name')
    }

    standard_request('LIST matching name (as user)', 200, 'data/0/offset_seconds', true, 'the_expected_name', 'the_unexpected_name')
  end

  get '/bookmarks?name=the_expected_name' do
    let(:authentication_token) { unconfirmed_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name')
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name')
    }

    standard_request('LIST matching name (as unconfirmed user)', 403, 'meta/error/links/confirm your account', true)
  end

  get '/bookmarks?name=the_expected_name' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, name: 'the_expected_name')
      FactoryGirl.create(:bookmark, name: 'the_unexpected_name')
    }

    standard_request('LIST matching name (with invalid token)', 401, 'meta/error/links/sign in', true)
  end

  # List bookmarks filtered by category
  # -----------------------------------

  get '/bookmarks?category=the_expected_category' do
    let(:authentication_token) { reader_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category')
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category')
    }

    standard_request('LIST matching category (as reader)', 200, 'data/0/offset_seconds', true, 'the_expected_category', 'the_unexpected_category')
  end

  get '/bookmarks?category=the_expected_category' do
    let(:authentication_token) { user_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category')
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category')
    }

    standard_request('LIST matching category (as user)', 200, 'data/0/offset_seconds', true, 'the_expected_category', 'the_unexpected_category')
  end

  get '/bookmarks?category=the_expected_category' do
    let(:authentication_token) { unconfirmed_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category')
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category')
    }

    standard_request('LIST matching category (as unconfirmed user)', 403, 'meta/error/links/confirm your account', true)
  end

  get '/bookmarks?category=the_expected_category' do
    let(:authentication_token) { invalid_token }

    let!(:extra_bookmark) {
      FactoryGirl.create(:bookmark, category: 'the_expected_category')
      FactoryGirl.create(:bookmark, category: 'the_unexpected_category')
    }

    standard_request('LIST matching category (with invalid token)', 401, 'meta/error/links/sign in', true)
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

    standard_request('CREATE (as admin)', 201, 'data/offset_seconds', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @writer_user)}.to_json }
    let(:authentication_token) { writer_token }

    standard_request('CREATE (as writer)', 201, 'data/offset_seconds', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @reader_user)}.to_json }
    let(:authentication_token) { reader_token }

    standard_request('CREATE (as reader)', 201, 'data/offset_seconds', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @user)}.to_json }
    let(:authentication_token) { user_token }

    standard_request('CREATE (as user)', 201, 'data/offset_seconds', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @other_user)}.to_json }
    let(:authentication_token) { other_user_token }

    standard_request('CREATE (as other user)', 201, 'data/offset_seconds', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @unconfirmed_user)}.to_json }
    let(:authentication_token) { unconfirmed_token }

    standard_request('CREATE (as unconfirmed user)', 403, 'meta/error/links/confirm your account', true)
  end

  post '/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false
    parameter :category, 'Category of bookmark', required: false

    let(:raw_post) { {bookmark: FactoryGirl.attributes_for(:bookmark, audio_recording_id: @bookmark.audio_recording_id, creator: @user)}.to_json }
    let(:authentication_token) { invalid_token }

    standard_request('CREATE (with invalid token)', 401, 'meta/error/links/sign in', true)
  end

  # New Item (#new)
  # ===============

  get '/bookmarks/new' do
    let(:authentication_token) { reader_token }
    standard_request('NEW (as reader)', 200, 'data/offset_seconds', true)
  end

  get '/bookmarks/new' do
    let(:authentication_token) { user_token }
    standard_request('NEW (as user)', 200, 'data/offset_seconds', true)
  end

  get '/bookmarks/new' do
    let(:authentication_token) { other_user_token }
    standard_request('NEW (as reader)', 200, 'data/offset_seconds', true)
  end

  get '/bookmarks/new' do
    let(:authentication_token) { unconfirmed_token }
    standard_request('NEW (as reader)', 403, 'meta/error/links/confirm your account', true)
  end

  get '/bookmarks/new' do
    let(:authentication_token) { invalid_token }
    standard_request('NEW (as reader)', 401, 'meta/error/links/sign in', true)
  end

  # Existing Item (#show)
  # ================

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    standard_request('SHOW (as reader)', 403, 'meta/error/links/request permissions', true)
  end

  get '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    standard_request('SHOW (as user)', 200, 'data/offset_seconds', true)
  end

  # Update (#update)
  # ================

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    standard_request('UPDATE (as reader)', 403, 'meta/error/links/request permissions')
  end

  put '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    standard_request('UPDATE (as user)', 204)
  end

  # Delete (#destroy)
  # ================

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    let(:id) { @bookmark.id }
    standard_request('DELETE (as reader)', 403, 'meta/error/links/request permissions')
  end

  delete '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token }
    let(:id) { @bookmark.id }
    standard_request('DELETE (as user)', 204)
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
                    contains: 'some text'
                }
            }
        }
    }.to_json }
    let(:authentication_token) { reader_token }
    standard_request('FILTER (as reader)', 200, 'data/0/category')
  end

end