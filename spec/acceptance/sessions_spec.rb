require 'rails_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

resource 'Sessions' do 

  # set header
  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  # authorization header is set for only some requests
  #header 'Authorization', :authentication_token

  let(:format) { 'json' }

  create_entire_hierarchy

  let!(:reader_user_password) { Devise.friendly_token.first(8) }

  before {
    reader_user.password = reader_user_password
    reader_user.password_confirmation = reader_user_password
    reader_user.save
  }

  # Sign in properties (#new)
  # ================

  get '/security/new' do
    standard_request_options(:get, 'security new (reader)', :ok, {expected_json_path: 'data/login'})
  end

  get '/security/new' do
    standard_request_options(:get, 'security new (admin)', :ok, {expected_json_path: 'data/password'})
  end

  # Sign in (#create)
  # ================

  post '/security' do
    parameter :email, 'User email (must provide one of email or login)', required: false
    parameter :login, 'User name or email (must provide one of email or login)', required: false
    parameter :password, 'User password', required: true

    let(:raw_post) { {email: reader_user.email, password: reader_user_password}.to_json }
    standard_request_options(:post, 'Sign In (reader using email: email)', :ok, {response_body_content: I18n.t('devise.sessions.signed_in'), expected_json_path: 'data/auth_token'})
  end

  post '/security' do
    parameter :email, 'User email (must provide one of email or login)', required: false
    parameter :login, 'User name or email (must provide one of email or login)', required: false
    parameter :password, 'User password', required: true

    let(:raw_post) { {login: reader_user.user_name, password: reader_user_password}.to_json }
    standard_request_options(:post, 'Sign In (reader using user name and password)', :ok, {response_body_content: I18n.t('devise.sessions.signed_in'), expected_json_path: 'data/auth_token'})
  end

  post '/security' do
    parameter :email, 'User email (must provide one of email or login)', required: false
    parameter :login, 'User name or email (must provide one of email or login)', required: false
    parameter :password, 'User password', required: true

    let(:raw_post) { {login: reader_user.email, password: reader_user_password}.to_json }
    standard_request_options(:post, 'Sign In (reader using email and password)', :ok, {response_body_content: I18n.t('devise.sessions.signed_in'), expected_json_path: 'data/auth_token'})
  end

  post '/security' do
    parameter :email, 'User email (must provide one of email or login)', required: false
    parameter :login, 'User name or email (must provide one of email or login)', required: false
    parameter :password, 'User password', required: true

    let(:raw_post) { {email: owner_user.email, password: owner_user.password}.to_json }
    standard_request_options(:post, 'Sign In (owner using email and password)', :ok, {response_body_content: I18n.t('devise.sessions.signed_in'), expected_json_path: 'data/auth_token'})
  end

  # Sign out (#destroy)
  # ==================

  delete '/security' do
    header 'Authorization', :authentication_token
    let(:authentication_token) { reader_token }
    standard_request_options(:delete, 'Sign Out (reader)', :ok, {response_body_content: I18n.t('devise.sessions.signed_out'), expected_json_path: 'data/message'})
  end

  delete '/security' do
    header 'Authorization', :authentication_token
    let(:authentication_token) { admin_token }
    standard_request_options(:delete, 'Sign Out (admin)', :ok, {response_body_content: I18n.t('devise.sessions.signed_out'), expected_json_path: 'data/message'})
  end


  # Get token (#show)
  # ============

  get '/security/user' do
    header 'Authorization', :authentication_token
    let(:authentication_token) { reader_token }
    standard_request_options(:get, 'Get Token with token auth in header (reader)', :ok, {response_body_content: '"user_name":"reader"', expected_json_path: 'data/auth_token'})
  end

  get '/security/user' do
    header 'Authorization', :authentication_token
    let(:authentication_token) { admin_token }
    standard_request_options(:get, 'Get Token with token auth in header (admin)', :ok, {response_body_content: '"user_name":"Admin"}', expected_json_path: 'data/auth_token'})
  end

  get '/security/user?user_token=:authentication_token' do
    let(:authentication_token) { Rack::Utils.escape(reader_user.authentication_token) }
    standard_request_options(:get, 'Get Token with token auth in qsp (reader)', :ok, {response_body_content: '"user_name":"reader"', expected_json_path: 'data/auth_token'})
  end

  get '/security/user?user_token=:authentication_token' do
    let(:authentication_token) { Rack::Utils.escape(admin_user.authentication_token) }
    standard_request_options(:get, 'Get Token with token auth in qsp (admin)', :ok, {response_body_content: '"user_name":"Admin"}', expected_json_path: 'data/auth_token'})
  end

  get '/security/user?email=:email&password=:password' do
    let(:email) { Rack::Utils.escape(reader_user.email) }
    let(:password) { Rack::Utils.escape(reader_user_password) }
    standard_request_options(:get, 'Get Token with email/pass auth in qsp (reader)', :ok, {response_body_content: '"user_name":"reader"', expected_json_path: 'data/auth_token'})
  end

  get '/security/user?login=:login&password=:password' do
    let(:login) { Rack::Utils.escape(reader_user.email) }
    let(:password) { Rack::Utils.escape(reader_user_password) }
    standard_request_options(:get, 'Get Token with login (email)/pass auth in qsp (reader)', :ok, {response_body_content: '"user_name":"reader"', expected_json_path: 'data/auth_token'})
  end

  get '/security/user?login=:login&password=:password' do
    let(:login) { Rack::Utils.escape(reader_user.user_name) }
    let(:password) { Rack::Utils.escape(reader_user_password) }
    standard_request_options(:get, 'Get Token with login (user name)/pass auth in qsp (reader)', :ok, {response_body_content: '"user_name":"reader"', expected_json_path: 'data/auth_token'})
  end


  # get '/security/sign_in' do
  #
  #
  #   example_request 'LIST' do
  #     status.should == 200
  #     response_body.should have_json_path('login')
  #     response_body.should have_json_path('password')
  #   end
  # end
  #
  # post '/security/sign_in' do
  #   let(:raw_post) { {email: permission.owner_user.email, password: permission.owner_user.password}.to_json }
  #
  #   example_request 'CREATE ' do
  #     status.should == 200
  #     response_body.should have_json_path('auth_token')
  #   end
  # end
  #
  # get '/security/sign_out' do
  #   header 'Authorization', :authentication_token
  #
  #   example_request 'Headers test' do
  #     headers.should == {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => authentication_token}
  #   end
  #
  #   example_request 'SHOW' do
  #     status.should == 200
  #   end
  # end
  #
  # get '/projects' do
  #   example_request 'Not logged in' do
  #     status.should == 401
  #     response_body.should have_json_path('meta')
  #     response_body.should have_json_path('meta/status')
  #     response_body.should have_json_path('meta/message')
  #     response_body.should have_json_path(get_json_error_path(:sign_up))
  #     response_body.should have_json_path(get_json_error_path(:confirm))
  #   end
  # end
  #
  # get '/projects/:id' do
  #   let(:id) { permission.owner_user.projects[0].id }
  #   header 'Authorization', :authentication_token_user
  #   example_request 'logged in but no access' do
  #     status.should == 403
  #     response_body.should have_json_path('meta')
  #     response_body.should have_json_path('meta/status')
  #     response_body.should have_json_path('meta/message')
  #     response_body.should have_json_path(get_json_error_path(:permissions))
  #   end
  # end


end