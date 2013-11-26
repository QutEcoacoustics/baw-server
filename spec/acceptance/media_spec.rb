require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

def standard_media_parameters

  parameter :audio_recording_id, 'Requested audio recording id (in path/route)', required: true

  parameter :format,        'Required format of the audio segment (defaults: json; alternatives: mp3|webm|ogg|png). Use json if requesting metadata', :required => true
  parameter :start_offset,  'Start time of the audio segment in seconds'
  parameter :end_offset,    'End time of the audio segment in seconds'

  let(:start_offset)  { '1' }
  let(:end_offset)    { '2' }

  let(:raw_post) { params.to_json }
end

# https://github.com/zipmark/rspec_api_documentation
resource 'Media' do

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  # default format
  let(:format)                {'json'}

  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
  end

  # prepare ids needed for paths in requests below
  let(:project_id)            {@write_permission.project.id}
  let(:site_id)               {@write_permission.project.sites[0].id}
  let(:audio_recording_id)    {@write_permission.project.sites[0].audio_recordings[0].id}

  # prepare authentication_token for different users
  let(:writer_token)          {"Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token)          {"Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:unconfirmed_token)     {"Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }

  ################################
  # MEDIA GET
  ################################
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.json' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { writer_token}
    standard_request('MEDIA (as writer)', 200, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.json' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token}
    standard_request('MEDIA (as reader)', 200, nil, true)
  end

  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.mp4' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { reader_token}
    standard_request('MEDIA (invalid format (mp4), as reader)', 415, nil, true)
  end
  get '/projects/:project_id/sites/:site_id/audio_recordings/:audio_recording_id/media.json' do
    parameter :project_id, 'Requested project ID (in path/route)', required: true
    parameter :site_id, 'Requested site ID (in path/route)', required: true
    standard_media_parameters
    let(:authentication_token) { unconfirmed_token}
    standard_request('MEDIA (as unconfirmed user)', 401, nil, true)
  end

  get '/audio_recordings/:audio_recording_id/media.json' do
    standard_media_parameters
    let(:authentication_token) { reader_token}
    standard_request('MEDIA (as reader with shallow path)', 200, nil, true)
  end
  get '/audio_recordings/:audio_recording_id/media.mp4' do
    standard_media_parameters
    let(:authentication_token) { reader_token}
    standard_request('MEDIA (invalid format (mp4), as reader with shallow path)', 415, nil, true)
  end

end
