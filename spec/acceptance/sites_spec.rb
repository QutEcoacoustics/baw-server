require 'spec_helper'
require 'rspec_api_documentation/dsl'
require 'helpers/acceptance_spec_helper'

# https://github.com/zipmark/rspec_api_documentation
resource 'Sites' do

  header 'Accept', 'application/json'
  header 'Content-Type', 'application/json'
  header 'Authorization', :authentication_token

  let(:format) { 'json' }

  # prepare ids needed for paths in requests below
  let(:project_id) { @write_permission.project.id }
  let(:id) { @write_permission.project.sites[0].id }

  # prepare authentication_token for different users
  let(:writer_token) { "Token token=\"#{@write_permission.user.authentication_token}\"" }
  let(:reader_token) { "Token token=\"#{@read_permission.user.authentication_token}\"" }
  let(:admin_token) { "Token token=\"#{@admin.authentication_token}\"" }

  # Create post parameters from factory
  let(:post_attributes) { FactoryGirl.attributes_for(:site) }
  let(:post_attributes_with_lat_long) { FactoryGirl.attributes_for(:site_with_lat_long) }


  before(:each) do
    # this creates a @write_permission.user with write access to @write_permission.project,
    # a @read_permission.user with read access, as well as
    # a site, audio_recording and audio_event having off the project (see permission_factory.rb)
    #puts 'Creating permissions for Sites spec...'
    @write_permission = FactoryGirl.create(:write_permission) # has to be 'write' so that the uploader has access
    @read_permission = FactoryGirl.create(:read_permission, project: @write_permission.project)
    @admin = FactoryGirl.create(:admin)
    #puts '...permissions created for Sites spec.'
  end

  ################################
  # LIST
  ################################
  get '/projects/:project_id/sites' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('LIST (as writer)', 200, '0/longitude', true)
  end

  get '/projects/:project_id/sites' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('LIST (as reader)', 200, '0/longitude', true)
  end

  get '/projects/:project_id/sites' do
    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('LIST (with invalid token)', 401, nil, true)
  end


  ################################
  # CREATE
  ################################
  post '/projects/:project_id/sites' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    let(:raw_post) { {'site' => post_attributes}.to_json }

    standard_request('CREATE (as writer)', 201, 'longitude', true)

  end

  post '/projects/:project_id/sites' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    let(:raw_post) { {'site' => post_attributes}.to_json }

    standard_request('CREATE (as reader)', 403, nil, true)

  end

  post '/projects/:project_id/sites' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    let(:raw_post) { {'site' => post_attributes}.to_json }

    standard_request('CREATE (with invalid token)', 401, nil, true)

  end

  ################################
  # SHOW
  ################################
  get '/projects/:project_id/sites/:id' do

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    # Comparing json does not work here as newlines \n in text fields are translated into arrays
    #puts @permission.site.to_json
    #puts ActiveSupport::JSON.decode(@permission.site)
    #puts JSON.parse(response_body)
    #puts ActiveSupport::JSON.decode(response_body)
    #response_json = JSON.parse(response_body).to_s
    #response_body.should have_json_path('name')
    standard_request('SHOW (as writer)', 200, 'longitude', true)
  end

  get '/projects/:project_id/sites/:id' do
    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader)', 200, 'longitude', true)
  end

  get '/projects/:project_id/sites/:id' do
    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('SHOW (with invalid token)', 401, nil, true)
  end

  # shallow routes
  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { writer_token }

    standard_request('SHOW (as writer)', 200, 'project_ids', true)
  end

  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { reader_token }

    standard_request('SHOW (as reader)', 200, 'longitude', true)
  end

  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('SHOW (with invalid token)', 401, nil, true)
  end

  # latitude and longitude obfuscation
  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true
    let(:authentication_token) { reader_token }
    check_site_lat_long_response('latitude and longitude should be obfuscated for read permission', 200)
  end

  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true
    let(:authentication_token) { writer_token }
    check_site_lat_long_response('latitude and longitude should be obfuscated for write permission', 200)
  end

  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true
    let(:authentication_token) { "Token token=\"#{@write_permission.project.creator.authentication_token}\"" }
    check_site_lat_long_response('latitude and longitude should NOT be obfuscated for project creator', 200, false)
  end

  get '/sites/:id' do
    parameter :id, 'Requested site ID (in path/route)', required: true
    let(:authentication_token) { admin_token }
    check_site_lat_long_response('latitude and longitude should NOT be obfuscated for admin', 200, false)
  end

  ################################
  # UPDATE
  ################################
  put '/projects/:project_id/sites/:id' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { {'site' => post_attributes}.to_json }

    let(:authentication_token) { writer_token }

    # Comparing json does not work here as newlines \n in text fields are translated into arrays
    #puts @permission.site.to_json
    #puts ActiveSupport::JSON.decode(@permission.site)
    #puts JSON.parse(response_body)
    #puts ActiveSupport::JSON.decode(response_body)
    #response_json = JSON.parse(response_body).to_s
    #response_body.should have_json_path('name')
    standard_request('UPDATE (as writer)', 204, nil, true)
  end

  put '/projects/:project_id/sites/:id' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { {'site' => post_attributes}.to_json }

    let(:authentication_token) { reader_token }

    #puts "Existing sites: #{Site.all.inspect}"

    standard_request('UPDATE (as reader)', 403, nil, true)
  end

  put '/projects/:project_id/sites/:id' do
    parameter :name, 'Name of site', scope: :site, :required => true
    parameter :longitude, 'Longitude of site', scope: :site, :required => true
    parameter :latitude, 'Latitude of site', scope: :site, :required => true
    parameter :description, 'Description of site', scope: :site
    parameter :notes, 'Notes of site', scope: :site

    parameter :project_id, 'project ID (in path/route)', required: true
    parameter :id, 'Requested site ID (in path/route)', required: true

    let(:raw_post) { {'site' => post_attributes}.to_json }

    let(:authentication_token) { "Token token=\"INVALID TOKEN\"" }

    standard_request('UPDATE (with invalid token)', 401, nil, true)
  end
end