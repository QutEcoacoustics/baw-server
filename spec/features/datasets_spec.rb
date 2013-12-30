require 'spec_helper'

include Warden::Test::Helpers
Warden.test_mode!

describe 'CRUD Datasets as valid user with write permission' do
  before(:each) do
    #Capybara.current_driver = :webkit  # needed to test javascript UI with capybara, but couldn't get it to work
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end
    login_as @permission.user, scope: :user
  end

  it 'lists all datasets' do
    visit project_path(@project)
    #save_and_open_page
    page.should have_content('Datasets')
    page.should have_content(@dataset.name)
  end

  it 'shows dataset details' do
    visit project_dataset_path(@project, @dataset)
    #save_and_open_page
    page.should have_content(@dataset.name)
    page.should have_link('Edit Dataset')
    page.should have_link('Add New Dataset')
    page.should_not have_link('Delete')
  end

  it 'creates new dataset when filling out form correctly' do
    visit new_project_dataset_path(@project)
    #save_and_open_page
    fill_in 'dataset[name]', with: 'test name'
    select @site.name, from: 'dataset[site_ids][]'
    #check 'dataset[has_time]'  # javascript is not loaded, hence it cannot test filling out time and date
    #fill_in 'dataset[start_time]', with: '6:00'
    #fill_in 'dataset[end_time]', with: '8:00'
    #check 'dataset[has_date]'
    #fill_in 'dataset[start_date]', with: '23/07/2013'
    #fill_in 'dataset[end_date]', with: '24/07/2013'
    #select 'Wind', from: 'dataset[filters]'
    #fill_in 'dataset[number_of_samples]', with: '100'
    #select 'None', from: 'dataset[number_of_tags]'
    #select 'Human', from: 'dataset[types_of_tags]'
    select 'General', from: 'dataset[types_of_tags][]'
    select 'Common name', from: 'dataset[types_of_tags][]'
    click_button 'Create Dataset'
    page.should have_content('test name')
    page.should have_content('Dataset was successfully created.')
  end

  it 'Fails to create new dataset when filling out form incomplete' do
    visit new_project_dataset_path(@project)
    click_button 'Create Dataset'
    #save_and_open_page
    page.should have_content('Please review the problems below:')
  end

  it 'updates dataset when filling out form correctly' do
    visit edit_project_dataset_path(@project, @dataset)
    #save_and_open_page
    fill_in 'dataset[name]', with: 'test name'
    click_button 'Update Dataset'
    page.should have_content('test name')
  end

  it 'shows errors when updating form incorrectly' do
    visit edit_project_dataset_path(@project, @dataset)
    #save_and_open_page
    fill_in 'dataset[name]', with: ''
    click_button 'Update Dataset'
    page.should have_content('Please review the problems below:')
    page.should have_content('can\'t be blank')
  end

  it 'successfully deletes the dataset' do
    visit project_dataset_path(@project, @dataset)
    #save_and_open_page
    page.has_xpath? "//a[@href=\"/projects/#{@project.id}/datasets/#{@dataset.id}\" and @data-method=\"delete\" and @data-confirm=\"Are you sure?\"]"
    expect { page.driver.delete project_dataset_path(@project, @dataset) }.to change(Dataset, :count).by(-1)
    page.driver.response.should be_redirect
    #visit page.driver.response.location
    #save_and_open_page
  end
end

describe 'CRUD Datasets as valid user with read permission' do
  before(:each) do
    @permission = FactoryGirl.create(:read_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end
    login_as @permission.user, scope: :user
  end

  it 'lists all datasets' do
    visit project_path(@project)
    page.should have_content('Datasets')
    page.should have_content(@dataset.name)
  end

  it 'shows dataset details' do
    visit project_dataset_path(@project, @dataset)
    page.should have_content(@dataset.name)
    page.should_not have_link('Edit Dataset')
    page.should_not have_link('Add New Dataset')
    page.should_not have_link('Delete')
  end

  it 'rejects access to create project dataset' do
    visit new_project_dataset_path(@project)
    page.should have_content('You are not authorized to access this page.')
  end

  it 'rejects access to update project dataset' do
    visit edit_project_dataset_path(@project, @dataset)
    page.should have_content('You are not authorized to access this page.')
  end
end

describe 'CRUD Datasets as valid user with no permission' do
  before(:each) do
    @permission = FactoryGirl.create(:read_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  it 'lists all datasets' do
    visit project_path(@project)
    page.should have_content('You are not authorized to access this page.')
  end

  it 'shows dataset details' do
    visit project_dataset_path(@project, @dataset)
    page.should have_content('You are not authorized to access this page.')
    page.should_not have_link('Edit Dataset')
    page.should_not have_link('Add New Dataset')
    page.should_not have_link('Delete')
  end

  it 'rejects access to create project dataset' do
    visit new_project_dataset_path(@project)
    page.should have_content('You are not authorized to access this page.')
  end

  it 'rejects access to update project dataset' do
    visit edit_project_dataset_path(@project, @dataset)
    page.should have_content('You are not authorized to access this page.')
  end
end

describe 'Delete Dataset as admin user' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end

    admin = FactoryGirl.create(:admin)
    login_as admin, scope: :user
  end

  it 'successfully deletes the entity' do
    visit project_dataset_path(@project, @dataset)
    #save_and_open_page
    page.should have_link('Delete Dataset')
    page.has_xpath? "//a[@href=\"/projects/#{@project.id}/datasets/#{@dataset.id}\" and @data-method=\"delete\" and @data-confirm=\"Are you sure?\"]"

    expect { first(:link, 'Delete').click }.to change(Dataset, :count).by(-1)

    #expect { page.driver.delete project_dataset_path(@project, @dataset) }.to change(Dataset, :count).by(-1)
    #page.driver.response.should be_redirect

    #visit page.driver.response.location
    #save_and_open_page
  end

end