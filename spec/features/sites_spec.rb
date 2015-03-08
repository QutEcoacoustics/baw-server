require 'spec_helper'

describe 'CRUD Sites as valid user with write permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    login_as @permission.user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(@project)
    expect(page).to have_content('Sites')
    expect(page).to have_content(@site.name)
  end

  it 'shows site details' do
    visit project_site_path(@project, @site)
    expect(page).to have_content(@site.name)
    expect(page).to have_link('Edit Site')
    expect(page).not_to have_link('Add New Site')
    expect(page).not_to have_link('Delete')
  end

  it 'creates new site when filling out form correctly' do
    url = new_project_site_path(@project)
    visit url
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[description]', with: 'description'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Create Site'
    expect(page).to have_content('test name')
    expect(page).to have_content('Site was successfully created.')
  end

  it 'Fails to create new site when filling out form incomplete' do
    url = new_project_site_path(@project)
    visit url
    #save_and_open_page
    click_button 'Create Site'
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates site when filling out form correctly' do
    visit edit_project_site_path(@project, @site)
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[description]', with: 'description'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Update Site'
    expect(page).to have_content('test name')
  end

  it 'shows errors when updating form incorrectly' do
    visit edit_project_site_path(@project, @site)
    #save_and_open_page
    fill_in 'site[name]', with: ''
    click_button 'Update Site'
    expect(page).to have_content('Please review the problems below:')
    expect(page).to have_content('can\'t be blank')
  end

  it 'downloads csv file successfully' do
    visit project_site_path(@project, @site)
    expect(page).to have_content('Annotations (csv)')
    click_link('Annotations (csv)')

    expected_url = "#{data_request_url}?annotation_download[project_id]=#{@project.id}&annotation_download[site_id]=#{@site.id}&annotation_download[name]=#{CGI::escape(@site.name)}"

    expect(current_url).to eq(expected_url)
    expect(page).to have_content("The CSV file containing annotations for #{@site.name} will download shortly.")

    click_link('here')

    expected_url = download_site_audio_events_url(@project, @site)
    expect(current_url).to eq(expected_url)

    expect(page).to have_content('Annotation Id, Audio Recording Id, Start Date, Start Time, End Date, End Time, Duration, Timezone, Max Frequency (hz), Min Frequency (hz), Project Ids, Project Names, Site Id, Site Name, Created By Id, Created By Name, Listen Url, Library Url, Tag 1 Id, Tag 1 Text, Tag 1 Type, Tag 1 Is Taxanomic, Tag 2 Id, Tag 2 Text, Tag 2 Type, Tag 2 Is Taxanomic, Tag 3 Id, Tag 3 Text, Tag 3 Type, Tag 3 Is Taxanomic, Tag 4 Id, Tag 4 Text, Tag 4 Type, Tag 4 Is Taxanomic')

    expect(page.response_headers['Content-Disposition']).to include('attachment; filename="')
    expect(page.response_headers['Content-Type']).to eq('text/csv')
  end
end

describe 'CRUD Sites as valid user with read permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:read_permission)
    @project = @permission.project
    @site = @project.sites[0]
    login_as @permission.user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(@project)
    expect(page).to have_content('Sites')
    expect(page).to have_content(@site.name)
  end

  it 'shows site details' do
    visit project_site_path(@project, @site)
    expect(page).to have_content(@site.name)
    expect(page).not_to have_link('Edit Site')
    expect(page).not_to have_link('Add New Site')
    expect(page).not_to have_link('Delete')
  end

  it 'rejects access to create project site' do
    visit new_project_site_path(@project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to update project site' do
    visit edit_project_site_path(@project, @site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end

describe 'CRUD Sites as valid user with no permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:read_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(@project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'shows site details' do
    visit project_site_path(@project, @site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))

  end

  it 'rejects access to create project site' do
    visit new_project_site_path(@project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'rejects access to update project site' do
    visit edit_project_site_path(@project, @site)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end

describe 'Delete Site as admin user', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]

    admin = FactoryGirl.create(:admin)
    login_as admin, scope: :user
  end

  it 'successfully deletes the entity' do
    visit project_site_path(@project, @site)
    #save_and_open_page
    expect(page).to have_link('Delete Site')
    page.has_xpath? "//a[@href=\"/projects/#{@project.id}/sites/#{@site.id}\" and @data-method=\"delete\" and @data-confirm=\"Are you sure?\"]"

    expect { first(:link, 'Delete').click }.to change(Site, :count).by(-1)

    #expect { page.driver.delete project_dataset_path(@project, @dataset) }.to change(Dataset, :count).by(-1)
    #page.driver.response.should be_redirect

    #visit page.driver.response.location
    #save_and_open_page
  end

end