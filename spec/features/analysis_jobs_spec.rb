require 'spec_helper'

describe 'CRUD Jobs as valid user with write permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @project = @permission.project
    @site = @project.sites[0]
    @saved_search = FactoryGirl.create(:saved_search, project: @project) do |saved_search|
      saved_search.projects << @project
    end
    @job = FactoryGirl.create(:analysis_job, saved_search: @saved_search, creator: @permission.user)
    @script = @job.script
    login_as @permission.user, scope: :user
  end

  it 'does not list all jobs' do
    visit project_path(@project)
    #save_and_open_page
    expect(page).not_to have_content('Jobs')
    expect(page).not_to have_content(@job.name)
  end

  it 'shows job details' do
    visit project_dataset_job_path(@project, @dataset, @job)
    #save_and_open_page
    expect(page).to have_content(@job.name)
    expect(page).to have_link('Edit Job')
    expect(page).to have_link('Add New Job')
    expect(page).not_to have_link('Delete')
  end

  it 'creates new job when filling out form correctly' do
    visit new_project_job_path(@project)
    #save_and_open_page
    fill_in 'job[name]', with: 'test name'
    fill_in 'job[annotation_name]', with: 'test annotation name'
    select @script.name, from: 'job[script_id]'
    fill_in 'job[script_settings]', with: 'test name'
    fill_in 'job[description]', with: 'description'
    click_button 'Create Job'
    # jobs are not listed on project page for now
    expect(page).not_to have_content('test name')
    expect(page).to have_content('Analysis job was successfully created.')
  end


  it 'Fails to create new job when filling out form incomplete' do
    visit new_project_job_path(@project)
    click_button 'Create Job'
    #save_and_open_page
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates job when filling out form correctly' do
    visit edit_project_job_path(@project, @job)
    #save_and_open_page
    fill_in 'job[name]', with: 'test name'
    click_button 'Update Job'
    expect(page).to have_content('test name')
  end


end