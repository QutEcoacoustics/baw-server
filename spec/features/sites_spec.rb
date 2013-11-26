require 'spec_helper'

include Warden::Test::Helpers
Warden.test_mode!

describe 'CRUD Sites as valid user with write permission' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    login_as @permission.user, scope: :user
  end

  it 'lists all sites' do
    visit project_path(@project)
    page.should have_content('Sites')
    page.should have_content(@site.name)
  end

  it 'shows site details' do
    visit project_site_path(@project, @site)
    page.should have_content(@site.name)
    page.should have_link('Edit Site')
    page.should have_link('Add New Site')
    page.should_not have_link('Delete')
  end

  it 'creates new site when filling out form correctly' do
    visit new_project_site_path(@project)
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[notes]', with: 'notes'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Create Site'
    page.should have_content('test name')
    page.should have_content('Site was successfully created.')
  end

  it 'Fails to create new site when filling out form incomplete' do
    visit new_project_site_path(@project)
    click_button 'Create Site'
    #save_and_open_page
    page.should have_content('Please review the problems below:')
  end

  it 'updates site when filling out form correctly' do
    visit edit_project_site_path(@project, @site)
    #save_and_open_page
    fill_in 'site[name]', with: 'test name'
    fill_in 'site[notes]', with: 'notes'
    attach_file('site[image]', 'public/images/user/user-512.png')
    click_button 'Update Site'
    page.should have_content('test name')
  end

  describe 'CRUD Sites as valid user with read permission' do
    before(:each) do
      @permission = FactoryGirl.create(:read_permission)
      @project = @permission.project
      @site = @project.sites[0]
      login_as @permission.user, scope: :user
    end

    it 'lists all sites' do
      visit project_path(@project)
      page.should have_content('Sites')
      page.should have_content(@site.name)
    end

    it 'shows site details' do
      visit project_site_path(@project, @site)
      page.should have_content(@site.name)
      page.should_not have_link('Edit Site')
      page.should_not have_link('Add New Site')
      page.should_not have_link('Delete')
    end

    it 'rejects access to create project site' do
      visit new_project_site_path(@project)
      page.should have_content('You are not authorized to access this page.')
    end

    it 'rejects access to update project site' do
      visit edit_project_site_path(@project, @site)
      page.should have_content('You are not authorized to access this page.')
    end
  end

  describe 'CRUD Sites as valid user with no permission' do
    before(:each) do
      @permission = FactoryGirl.create(:read_permission)
      @project = @permission.project
      @site = @project.sites[0]
      @user = FactoryGirl.create(:user) # creating new user with no permission to login
      login_as @user, scope: :user
    end

    it 'lists all sites' do
      visit project_path(@project)
      page.should have_content('You are not authorized to access this page.')
    end

    it 'shows site details' do
      visit project_site_path(@project, @site)
      page.should have_content('You are not authorized to access this page.')

    end

    it 'rejects access to create project site' do
      visit new_project_site_path(@project)
      page.should have_content('You are not authorized to access this page.')
    end

    it 'rejects access to update project site' do
      visit edit_project_site_path(@project, @site)
      page.should have_content('You are not authorized to access this page.')
    end
  end
end
