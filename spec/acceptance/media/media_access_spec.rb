# frozen_string_literal: true

require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'
require 'helpers/resque_helper'
require 'fixtures/fixtures'

# https://github.com/zipmark/rspec_api_documentation
resource 'Media' do
  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  # default format
  let(:format) { 'json' }

  # prepare ids needed for paths in requests below
  let(:audio_recording_id) { audio_recording.id }

  def token(symbol)
    self.send(symbol) # rubocop:disable Style/RedundantSelf
  end

  shared_examples_for :media_permissions_ok do |current_user, name|
    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      header 'Authorization', :authentication_token if current_user != :no_token
      let(:authentication_token) { token(current_user) }
      let(:format) { 'json' }
      standard_request_options(
        :get,
        "MEDIA (as #{current_user}, #{name})",
        :ok,
        { expected_json_path: 'data/recording/channel_count' }
      )
    end
  end

  shared_examples_for :media_permissions_forbidden do |current_user, name|
    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      header 'Authorization', :authentication_token if current_user != :no_token
      let(:authentication_token) { token(current_user) }
      let(:format) { 'json' }
      standard_request_options(
        :get,
        "MEDIA (as #{current_user}, #{name})",
        :forbidden,
        { expected_json_path: get_json_error_path(:permissions) }
      )
    end
  end

  shared_examples_for :media_permissions_unauthorized do |current_user, name|
    get '/audio_recordings/:audio_recording_id/media.:format' do
      standard_media_parameters
      header 'Authorization', :authentication_token if current_user != :no_token
      let(:authentication_token) { token(current_user) }
      let(:format) { 'json' }
      standard_request_options(
        :get,
        "MEDIA (as #{current_user}, #{name})",
        :unauthorized,
        { expected_json_path: get_json_error_path(:sign_up) }
      )
    end
  end

  describe 'basic project access:' do
    create_audio_recordings_hierarchy(method(:prepare_project))

    it_should_behave_like :media_permissions_ok, :admin_token, ''
    it_should_behave_like :media_permissions_ok, :owner_token, ''
    it_should_behave_like :media_permissions_ok, :writer_token, ''
    it_should_behave_like :media_permissions_ok, :reader_token, ''
    it_should_behave_like :media_permissions_forbidden, :no_access_token, ''
    it_should_behave_like :media_permissions_unauthorized, :invalid_token, ''
    it_should_behave_like :media_permissions_unauthorized, :no_token, ''
  end

  describe 'logged in general project access:' do
    create_audio_recordings_hierarchy(method(:prepare_project_logged_in))

    it_should_behave_like :media_permissions_ok, :admin_token, '+loggedin'
    it_should_behave_like :media_permissions_ok, :owner_token, '+loggedin'
    it_should_behave_like :media_permissions_ok, :writer_token, '+loggedin'
    it_should_behave_like :media_permissions_ok, :reader_token, '+loggedin'
    it_should_behave_like :media_permissions_ok, :no_access_token, '+loggedin'
    it_should_behave_like :media_permissions_unauthorized, :invalid_token, '+loggedin'
    it_should_behave_like :media_permissions_unauthorized, :no_token, '+loggedin'
  end

  describe 'anonymous project access:' do
    create_audio_recordings_hierarchy(method(:prepare_project_anon))

    it_should_behave_like :media_permissions_ok, :admin_token, '+anonymous'
    it_should_behave_like :media_permissions_ok, :owner_token, '+anonymous'
    it_should_behave_like :media_permissions_ok, :writer_token, '+anonymous'
    it_should_behave_like :media_permissions_ok, :reader_token, '+anonymous'

    # This is an interesting case where logged in access is not granted. So a
    # even though the project allows anonymous access, it does not allow logged
    # in access. The user doesn't have any other permissions on the project and
    # is thus rejected. Doesn't make sense, but it is a valid corner case.
    it_should_behave_like :media_permissions_forbidden, :no_access_token, '+anonymous'

    # An invalid token (i.e. malformed) is an error case. So even with
    # completely public anonymous access to this data, the user is rejected.
    # Malformed is not the same as "no access by default", or "i have no token at all",
    # or "my token has expired". They all should work.
    it_should_behave_like :media_permissions_unauthorized, :invalid_token, '+anonymous'
    it_should_behave_like :media_permissions_ok, :no_token, '+anonymous'
  end

  describe 'anonymous and logged in general project access:' do
    create_audio_recordings_hierarchy(method(:prepare_project_anon_and_logged_in))

    it_should_behave_like :media_permissions_ok, :admin_token, '+anonymous+logged_in'
    it_should_behave_like :media_permissions_ok, :owner_token, '+anonymous+logged_in'
    it_should_behave_like :media_permissions_ok, :writer_token, '+anonymous+logged_in'
    it_should_behave_like :media_permissions_ok, :reader_token, '+anonymous+logged_in'
    it_should_behave_like :media_permissions_ok, :no_access_token, '+anonymous+logged_in'

    # An invalid token (i.e. malformed) is an error case.
    it_should_behave_like :media_permissions_unauthorized, :invalid_token, '+anonymous+logged_in'
    it_should_behave_like :media_permissions_ok, :no_token, '+anonymous+logged_in'
  end
end
