require 'spec_helper'
require 'rspec_api_documentation/dsl'

# https://github.com/zipmark/rspec_api_documentation
resource 'Sessions' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'

  let(:format) { 'json' }

  # Create post parameters from factory
  let(:authentication_token) { "Token token=\"#{@permission.user.authentication_token}\"" }
  let(:authentication_token_user) { "Token token=\"#{@user.authentication_token}\"" }


  before(:each) do
    # this creates a @permission.user with read access to @permission.project, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user)
  end

  get '/security/sign_in' do
    example_request 'LIST' do
      status.should == 200
      response_body.should have_json_path('login')
      response_body.should have_json_path('password')
    end
  end

  post '/security/sign_in' do
    let(:raw_post) { {email: @permission.user.email, password: @permission.user.password}.to_json }

    example_request 'CREATE ' do
      status.should == 200
      response_body.should have_json_path('auth_token')
    end
  end

  get '/security/sign_out' do
    header 'Authorization', :authentication_token

    example_request 'Headers test' do
      headers.should == {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => authentication_token}
    end

    example_request 'SHOW' do
      status.should == 200
    end
  end

  get '/projects' do
    example_request 'Not logged in' do
      status.should == 401
      response_body.should have_json_path('meta')
      response_body.should have_json_path('meta/status')
      response_body.should have_json_path('meta/message')
      response_body.should have_json_path('meta/error/links/sign in')
      response_body.should have_json_path('meta/error/links/confirm your account')
    end
  end

  get '/projects/:id' do
    let(:id) { @permission.user.projects[0].id }
    header 'Authorization', :authentication_token_user
    example_request 'logged in but no access' do
      status.should == 403
      response_body.should have_json_path('meta')
      response_body.should have_json_path('meta/status')
      response_body.should have_json_path('meta/message')
      response_body.should have_json_path('meta/error/links/request permissions')
    end
  end


end