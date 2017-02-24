require 'rails_helper'

describe 'CRUD Sites as valid user with owner permission', type: :feature do

  create_entire_hierarchy

  before(:each) do
    login_as owner_user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(project)
    expect(page).to have_content('Sites')
    expect(page).to have_content(site.name)
  end

  it 'shows site details' do
    visit project_site_path(project, site)
    expect(page).to have_content(site.name)
    expect(page).to have_link('Edit this site')
    expect(page).to have_link('Explore audio')
    expect(page).to have_link('Listen to audio')
    expect(page).to have_link('Download annotations')
    expect(page).not_to have_button('Delete this site')
  end

  it 'creates new site when filling out form correctly' do
    url = new_project_site_path(project)
    visit url
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[description]', with: 'description'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content('test name')
    expect(page).to have_content('Site was successfully created.')
  end

  it 'Fails to create new site when filling out form incomplete' do
    url = new_project_site_path(project)
    visit url
    #save_and_open_page
    click_button 'Submit'
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates site when filling out form correctly' do
    visit edit_project_site_path(project, site)
    expect(page).to have_content(site.name)
    expect(page).to have_content('Original name is')
    fill_in 'site[name]', with: 'test name 2'
    click_button 'Submit'
    expect(page).to have_content('test name 2')
    expect(page).to have_content('Site was successfully updated.')
  end

  it 'shows errors when updating form incorrectly' do
    visit edit_project_site_path(project, site)
    # save_and_open_page
    fill_in 'site[name]', with: ''
    click_button 'Submit'
    expect(page).to have_content('Please review the problems below:')
    expect(page).to have_content('can\'t be blank')
    expect(page).to have_content(site.name)

  end

  it 'downloads csv file successfully' do
    site.tzinfo_tz = 'Australia - Brisbane'
    site.save!

    visit project_site_path(project, site)
    expect(page).to have_content('Download annotations')
    click_link('Download annotations')

    expected_url = "#{data_request_url}?selected_project_id=#{project.id}&selected_site_id=#{site.id}&selected_timezone_name=Brisbane"

    expect(current_url).to eq(expected_url)
    expect(page).to have_content("Please select the time zone for the CSV file containing annotations for #{site.name}. Select time zone")

    select('(GMT+10:00) Brisbane', from: 'select_timezone_offset')
    click_link('Download Annotations')

    expected_url = download_site_audio_events_url(project, site, selected_timezone_name: 'Brisbane')
    expect(current_url).to eq(expected_url)

    expect(page).to have_content('audio_event_id, audio_recording_id, audio_recording_uuid, audio_recording_start_date_brisbane_10_00, audio_recording_start_time_brisbane_10_00, audio_recording_start_datetime_brisbane_10_00, event_created_at_date_brisbane_10_00, event_created_at_time_brisbane_10_00, event_created_at_datetime_brisbane_10_00, projects, site_id, site_name, event_start_date_brisbane_10_00, event_start_time_brisbane_10_00, event_start_datetime_brisbane_10_00, event_start_seconds, event_end_seconds, event_duration_seconds, low_frequency_hertz, high_frequency_hertz, is_reference, created_by, updated_by, common_name_tags, common_name_tag_ids, species_name_tags, species_name_tag_ids, other_tags, other_tag_ids, listen_url, library_url')

    expect(page.response_headers['Content-Disposition']).to include('attachment; filename="')
    expect(page.response_headers['Content-Type']).to eq('text/csv')

    site.tzinfo_tz = nil
    site.save!

  end

  it 'rejects access to view project site harvest' do
    visit harvest_project_site_path(project, site, format: :yml)
    expect(page).to have_content('# this needs to be set manually')
  end

  it 'allows access to view project site upload' do
    visit upload_instructions_project_site_path(project, site)
    expect(page).to have_content('Follow these instructions to upload audio to the site')
  end

end

describe 'CRUD Sites as valid user with read permission', type: :feature do

  create_entire_hierarchy

  before(:each) do
    login_as reader_user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(project)
    expect(page).to have_content('Sites')
    expect(page).to have_content(site.name)
  end

  it 'shows site details' do
    visit project_site_path(project, site)
    expect(page).to have_content(site.name)
    expect(page).not_to have_link('Edit site')
    expect(page).not_to have_button('Delete this site')
  end

  it 'allows access to create project site' do
    visit new_project_site_path(project)
    expect(page).to have_content('New Site')
  end

  # we allow access to new for API (so form as well) but we don't allow the form to work
  it 'rejects a new site when filling out form correctly' do
    url = new_project_site_path(project)
    visit url
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[description]', with: 'description'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to update project site' do
    visit edit_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to view project site harvest' do
    visit harvest_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to view project site upload' do
    visit upload_instructions_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end

describe 'CRUD Sites as valid user with no permission', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as no_access_user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'shows site details' do
    visit project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))

  end

  it 'allows access to create project site' do
    visit new_project_site_path(project)
    expect(page).to have_content('New Site')
  end

  # we allow access to new for API (so form as well) but we don't allow the form to work
  it 'rejects a new site when filling out form correctly' do
    url = new_project_site_path(project)
    visit url
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[description]', with: 'description'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to update project site' do
    visit edit_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to view project site harvest' do
    visit harvest_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to view project site upload' do
    visit upload_instructions_project_site_path(project, site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end

describe 'Delete Site as admin user', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as admin_user, scope: :user
  end

  it 'successfully deletes the entity' do
    visit project_site_path(project, site)
    #save_and_open_page
    expect(page).to have_button('Delete this site')
    page.has_xpath? "//form[@action=\"/projects/#{project.id}/sites/#{site.id}\" and @data-method=\"delete\" and @data-confirm=\"Are you sure?\"]"

    expect { first(:button, 'Delete').click }.to change(Site, :count).by(-1)

    #expect { page.driver.delete project_dataset_path(project, dataset) }.to change(Dataset, :count).by(-1)
    #page.driver.response.should be_redirect

    #visit page.driver.response.location
    #save_and_open_page
  end

  it 'can access harvester page' do
    visit harvest_project_site_path(project, site, format: :yml)
    expect(page).to have_content('# this needs to be set manually')
  end

  it 'can access upload page' do
    visit upload_instructions_project_site_path(project, site)
    expect(page).to have_content('Follow these instructions to upload audio to the site')
  end

end

describe 'Delete Site as admin user', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as owner_user, scope: :user
  end

  it 'can access harvester page' do
    visit harvest_project_site_path(project, site, format: :yml)
    expect(page).to have_content('# this needs to be set manually')
  end

  it 'can access upload page' do
    visit upload_instructions_project_site_path(project, site)
    expect(page).to have_content('Follow these instructions to upload audio to the site')
  end

end