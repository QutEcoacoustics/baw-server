require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'AudioEventComments' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format) { 'json' }

  before(:each) do
    # create projects, permissions, sites, etc needed for audio_event_comments
    @user1 = FactoryGirl.create(:user)
    @user2 = FactoryGirl.create(:user)
    @admin = FactoryGirl.create(:admin)

    #@project =


    # permission factories create one of all dependent models (project, site, audio_recording, ...)
    @write_permission = FactoryGirl.create(:write_permission)
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)

    @comment_1 = @write_permission.project.sites[0].audio_recordings[0].audio_events[0].comments[0]

    @write_permission_2 = FactoryGirl.create(:write_permission, project: @write_permission.project)
    @comment_2 = FactoryGirl.create(
        :audio_event_comment,
        comment: 'comment 2',
        creator: @write_permission_2.creator,
        audio_event: @write_permission_2.project.sites[0].audio_recordings[0].audio_events[0])

    @write_permission_creator = User.where(id: @write_permission.creator_id).first
    @write_permission_2_creator = User.where(id: @write_permission_2.creator_id).first
  end

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:writer_token_creator) {
    "Token token=\"#{@write_permission_creator.authentication_token}\""
  }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
  let(:admin_token) { "Token token=\"#{FactoryGirl.create(:admin).authentication_token}\"" }
  let(:post_attributes) { {comment: 'hello! :)'} }

  let(:writer_token_2) { "Token token=\"#{@write_permission_2.user.authentication_token}\"" }
  let(:writer_token_2_creator) { "Token token=\"#{@write_permission_2_creator.authentication_token}\"" }

  ################################
  # LIST
  ################################
  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:authentication_token) { writer_token }
    standard_request('LIST (as writer)', 200, '0/comment', true)
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:authentication_token) { reader_token }
    standard_request('LIST (as reader)', 200, '0/comment', true)
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:authentication_token) { admin_token }
    standard_request('LIST (as admin)', 200, '0/comment', true)
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:authentication_token) { unconfirmed_token }
    standard_request('LIST (as unconfirmed_token)', 403, nil, true)
  end

  get '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:authentication_token) { 'blah' }
    standard_request('CREATE (as invalid user)', 401, nil, true)
  end

  ################################
  # CREATE
  ################################
  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token }
    standard_request('CREATE (as writer)', 201, nil, true)
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request('CREATE (as reader)', 201, nil, true)
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request('CREATE (as admin)', 201, nil, true)
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request('CREATE (as unconfirmed user)', 403, nil, true)
  end

  post '/audio_events/:audio_event_id/comments' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { 'blah' }
    standard_request('CREATE (as invalid user)', 401, nil, true)
  end

  ################################
  # Update
  ################################
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token_creator }
    standard_request('UPDATE (as writer creator)', 204, nil, true)
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { reader_token }
    standard_request('UPDATE (as reader)', 403, nil, true)
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { admin_token }
    standard_request('UPDATE (as admin)', 204, nil, true)
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { unconfirmed_token }
    standard_request('UPDATE (as unconfirmed user)', 403, nil, true)
  end

  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { 'blah' }
    standard_request('UPDATE (as invalid user)', 401, nil, true)
  end

  # user can only update their own comments
  put '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_2.audio_event_id }
    let(:id) { @comment_2.audio_event_id }
    let(:raw_post) { {audio_event_comment: post_attributes}.to_json }
    let(:authentication_token) { writer_token_creator }
    standard_request('UPDATE (as writer updating non-owned comment)', 403, nil, true)
  end

  ################################
  # Destroy
  ################################
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:authentication_token) { writer_token_creator }
    standard_request('DESTROY (as writer creator)', 204, nil, true)
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:authentication_token) { reader_token }
    standard_request('DESTROY (as reader)', 403, nil, true)
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:authentication_token) { admin_token }
    standard_request('DESTROY (as admin)', 204, nil, true)
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:authentication_token) { unconfirmed_token }
    standard_request('DESTROY (as unconfirmed user)', 403, nil, true)
  end

  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_1.audio_event_id }
    let(:id) { @comment_1.id }
    let(:authentication_token) { 'blah' }
    standard_request('DESTROY (as invalid user)', 401, nil, true)
  end

  # users can only delete their own comments
  delete '/audio_events/:audio_event_id/comments/:id' do
    parameter :audio_event_id, 'Requested audio event id (in path/route)', required: true
    parameter :id, 'Requested audio event comment id (in path/route)', required: true
    let(:audio_event_id) { @comment_2.audio_event_id }
    let(:id) { @comment_2.id }
    let(:authentication_token) { writer_token_creator }
    standard_request('DESTROY (as writer deleting non-owned comment)', 403, nil, true)
  end

end