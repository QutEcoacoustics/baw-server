require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'


# https://github.com/zipmark/rspec_api_documentation
resource 'Projects' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) {'json'}

  # prepare ids needed for paths in requests below
  let(:id) {@write_permission.project.id}

  # prepare authentication_token for different users
  let(:writer_token)          {"Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token)          {"Token token=\"#{@read_permission.user.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:required_project_attributes) }


  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
  end

  ################################
  # LIST
  ################################
  get '/projects' do
    let(:authentication_token) { writer_token }
    standard_request('LIST (as confirmed_user)' ,200,'0/name', true)
  end

  get '/projects' do
    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request('LIST (as unconfirmed user)', 401, nil, true)
  end

  get '/projects' do
    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('LIST (with invalid token)', 401, nil, true)
  end

  ################################
  # CREATE
  ################################
  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }
    standard_request('CREATE (as confirmed user)', 201, 'name', true)

  end

  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request('CREATE (as unconfirmed user)', 401, nil, true)

  end

  post '/projects' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('CREATE (with invalid token)', 401, nil, true)

  end

  ################################
  # SHOW
  ################################
  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }
    standard_request('SHOW (as writer)' ,200,'name', true)

  end
  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }
    standard_request('SHOW (as reader)' ,200,'name', true)
  end

  get '/projects' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }
    standard_request('SHOW (as unconfirmed user)', 401, nil, true)
  end

  get '/projects/:id' do
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }
    standard_request('SHOW (with invalid token)' ,401, nil, true)

  end

  ################################
  # UPDATE
  ################################
  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    standard_request('UPDATE (as writer)' ,204, nil, true)
  end

  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    standard_request('UPDATE (as reader)' ,401,nil, true)
  end

  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('UPDATE (with invalid token)' ,401, nil, true)
  end


  put '/projects/:id' do
    parameter :name, 'Name of project', scope: :project, :required => true
    parameter :description, 'Description of project', scope: :project
    parameter :notes, 'Notes of project', scope: :project
    parameter :id, 'Requested project ID (in path/route)', required: true

    let(:raw_post) { {'project' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"#{FactoryGirl.create(:unconfirmed_user).authentication_token}\"" }

    standard_request('UPDATE (as unconfirmed user)' ,401, nil, true)
  end

end