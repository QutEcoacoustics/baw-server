require 'spec_helper'

include Warden::Test::Helpers
Warden.test_mode!

describe 'CRUD Jobs as valid user with write permission' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @dataset = FactoryGirl.create(:dataset, project: @project) do |dataset|
      dataset.sites << @site
    end
    @job = FactoryGirl.create(:job, dataset: @dataset, creator: @permission.user)
    @script = @job.script
    login_as @permission.user, scope: :user
  end

  it 'does not list all jobs' do
    visit project_path(@project)
    #save_and_open_page
    page.should_not have_content('Jobs')
    page.should_not have_content(@job.name)
  end

  it 'shows job details' do
    visit project_dataset_job_path(@project, @dataset, @job)
    #save_and_open_page
    page.should have_content(@job.name)
    page.should have_link('Edit Job')
    page.should have_link('Add New Job')
    page.should_not have_link('Delete')
  end

  it 'creates new job when filling out form correctly' do
    visit new_project_job_path(@project)
    #save_and_open_page
    fill_in 'job[name]', with: 'test name'
    fill_in 'job[annotation_name]', with: 'test annotation name'
    select @dataset.name, from: 'job[dataset_id]'
    select @script.name, from: 'job[script_id]'
    fill_in 'job[script_settings]', with: 'test name'
    fill_in 'job[description]', with: 'description'
    click_button 'Create Job'
    # jobs are not listed on project page for now
    page.should_not have_content('test name')
    page.should have_content('Analysis job was successfully created.')
  end


  it 'Fails to create new job when filling out form incomplete' do
    visit new_project_job_path(@project)
    click_button 'Create Job'
    #save_and_open_page
    page.should have_content('Please review the problems below:')
  end

  it 'updates job when filling out form correctly' do
    visit edit_project_job_path(@project, @job)
    #save_and_open_page
    fill_in 'job[name]', with: 'test name'
    click_button 'Update Job'
    page.should have_content('test name')
  end


end