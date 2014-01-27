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
  let(:format)                {'json'}

  before(:each) do
    @user = FactoryGirl.create(:user) 
    @bookmark = FactoryGirl.create(:bookmark)
  end

  # prepare ids needed for paths in requests below
  let(:user_account_id)       {@bookmark.creator.id}
  let(:audio_recording_id)    {@bookmark.audio_recording.id}
  let(:id)                    {@bookmark.id}

  # prepare authentication_token for different users
  let(:user_token)          {"Token token=\"#{@user.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) {FactoryGirl.attributes_for(:bookmark)}

  ################################
  # LIST
  ################################
  get 'user_accounts/:user_account_id/bookmarks' do
    parameter :user_account_id, 'Requested user_account ID (in path/route)', required: true
    let(:authentication_token) { user_token}
    standard_request('LIST for user_account (as user)', 200, '0/offset_seconds', true)
  end

  ################################
  # LIST
  ################################
  get 'audio_recordings/:audio_recording_id/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true

    let(:authentication_token) { user_token}
    standard_request('LIST for audio_recording (as user)', 200, '0/offset_seconds', true)
  end
  ################################
  # SHOW
  ################################
  get  '/bookmarks/:id' do
    parameter :id, 'Requested bookmark ID (in path/route)', required: true

    let(:authentication_token) { user_token}
    standard_request('SHOW (as user)', 200, 'offset_seconds', true)
  end

  ################################
  # CREATE
  ################################
  post 'audio_recordings/:audio_recording_id/bookmarks' do
    parameter :audio_recording_id, 'Requested audio_recording ID (in path/route)', required: true
    parameter :offset_seconds, 'Offset from start of audio recording to place bookmark', required: true
    parameter :name, 'Name for bookmark', required: false
    parameter :description, 'Description of bookmark', required: false

    let(:raw_post) { {'bookmark' => post_attributes}.to_json }

    let(:authentication_token) { user_token}

    standard_request('CREATE (as user)', 201, 'offset_seconds', true)
  end



end