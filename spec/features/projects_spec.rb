require 'spec_helper'

def select_by_value(id, value)
  option_xpath = "//*[@id='#{id}']/option[@value='#{value}']"
  option = find(:xpath, option_xpath).text
  page.select(option, from: id)
end

describe 'CRUD Projects as valid user with write permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    login_as @permission.user, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(@permission.project.name)
  end

  it 'shows project details' do
    visit project_path(@permission.project)
    expect(page).to have_content(@permission.project.name)
    expect(page).to have_link('Edit')
    expect(page).to have_link('Edit Permissions')
    expect(page).not_to have_link('Delete')
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end

  it 'Fails to create new project when filling out form incomplete' do
    visit new_project_path
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates project when filling out form correctly' do
    visit edit_project_path(@permission.project)
    #save_and_open_page
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content('test name')
  end

  it 'shows errors when updating form incorrectly' do
    visit edit_project_path(@permission.project)
    #save_and_open_page
    fill_in 'project[name]', with: ''
    click_button 'Submit'
    expect(page).to have_content('Please review the problems below:')
    expect(page).to have_content('can\'t be blank')
  end

end

describe 'CRUD Projects as valid user and project creator', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    login_as @permission.project.creator, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(@permission.project.name)
  end

  it 'shows project details' do
    visit project_path(@permission.project)
    expect(page).to have_content(@permission.project.name)
    expect(page).to have_link('Edit')
    expect(page).to have_link('Edit Permissions')
    expect(page).not_to have_link('Delete')
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    #save_and_open_page
    fill_in 'project_name', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end

  it 'updates project when filling out form correctly' do
    visit edit_project_path(@permission.project)
    #save_and_open_page
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content('test name')
  end

end

describe 'CRUD Projects as valid user with read permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:read_permission)
    login_as @permission.user, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(@permission.project.name)
  end

  it 'shows project details' do
    visit project_path(@permission.project)
    expect(page).to have_content(@permission.project.name)
    expect(page).not_to have_link('Edit')
    expect(page).not_to have_link('Edit Permissions')
    expect(page).not_to have_link('Delete')
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end


  it 'rejects access to update project' do
    visit edit_project_path(@permission.project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

end

describe 'CRUD Projects as valid user with no permissions', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  it 'lists all projects' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).not_to have_content(@permission.project.name)
  end

  it 'rejects access to show project details' do
    visit project_path(@permission.project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    fill_in 'project[notes]', with: 'notes'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end

  it 'rejects access to edit project details' do
    visit edit_project_path(@permission.project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

end

describe 'Delete Projects as admin user', :type => :feature do
  before(:each) do
    admin = FactoryGirl.create(:admin)
    login_as admin, scope: :user
  end

  it 'deletes a project' do
    permission = FactoryGirl.create(:write_permission)
    visit project_path(permission.project)
    expect(page).to have_link('Delete Project')
    expect { first(:link, 'Delete').click }.to change(Project, :count).by(-1)
  end
end

describe 'CRUD Projects as unconfirmed user', :type => :feature do
  before(:each) do
    @user = FactoryGirl.create(:unconfirmed_user) # creating new user unconfirmed user
    @permission = FactoryGirl.create(:write_permission)
    login_as @user, scope: :user
  end

  it 'reject access to list all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
  end

  it 'rejects access to show project details' do
    visit project_path(@permission.project)
    expect(current_path).to eq(project_path(@permission.project))
    expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
  end

  it 'rejects access to create a new project' do
    visit new_project_path
    expect(current_path).to eq(new_project_path)
    expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))

  end

  it 'rejects access to edit project details' do
    visit edit_project_path(@permission.project)
    expect(current_path).to eq(edit_project_path(@permission.project))
    expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
  end

end

describe 'request project access', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  it 'sends emails when form filled out successfully' do
    ActionMailer::Base.deliveries.clear

    visit new_access_request_projects_path
    #save_and_open_page
    expect(current_path).to eq(new_access_request_projects_path)
    fill_in 'access_request[reason]', with: 'testing testing'
    select_by_value('access_request_projects', @permission.project.id)
    #page.select @permission.project.name, from: 'access_request[projects][]'
    click_button 'Submit request'

    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Access request successfully submitted.')

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    email = ActionMailer::Base.deliveries[0]
    expect(email).to have_content(@permission.project.name)
    expect(email).to have_content(@permission.project.creator.user_name)
    expect(email).to have_content(@user.user_name)
  end

  it 'shows error when form not filled out correctly' do
    ActionMailer::Base.deliveries.clear

    visit new_access_request_projects_path
    #save_and_open_page
    expect(current_path).to eq(new_access_request_projects_path)
    #fill_in 'access_request[reason]', with: 'testing testing'
    select_by_value('access_request_projects', @permission.project.id)
    #page.select @permission.project.name, from: 'access_request[projects][]'
    click_button 'Submit request'

    expect(current_path).to eq(new_access_request_projects_path)
    expect(page).to have_content('Please select projects and provide reason for access.')

    expect(ActionMailer::Base.deliveries.size).to eq(0)
  end

  it 'shows error when form not filled out correctly' do
    ActionMailer::Base.deliveries.clear

    visit new_access_request_projects_path
    #save_and_open_page
    expect(current_path).to eq(new_access_request_projects_path)
    fill_in 'access_request[reason]', with: 'testing testing'
    #select_by_value('access_request_projects', @permission.project.id)
    #page.select @permission.project.name, from: 'access_request[projects][]'
    click_button 'Submit request'

    expect(current_path).to eq(new_access_request_projects_path)
    expect(page).to have_content('Please select projects and provide reason for access.')

    expect(ActionMailer::Base.deliveries.size).to eq(0)
  end
end
