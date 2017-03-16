require 'rails_helper'

def select_by_value(id, value)
  option_xpath = "//*[@id='#{id}']/option[@value='#{value}']"
  option = find(:xpath, option_xpath).text
  page.select(option, from: id)
end

describe 'CRUD Projects as valid user with write permission', type: :feature do

  create_entire_hierarchy

  before(:each) do
    login_as writer_user, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(project.name)
  end

  it 'shows project details' do
    visit project_path(project)
    expect(page).to have_content(project.name)
    expect(page).not_to have_link('Edit')
    expect(page).not_to have_link('Edit Permissions')
    expect(page).not_to have_link('Delete')
  end

  it 'lists the creator and owner' do
    visit project_path(project)
    expect(page).to have_content('Created by')
    expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
    expect(page).to have_content('Owned by')
    expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
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
    visit edit_project_path(project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

end

describe 'CRUD Projects as valid user and project creator', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as project.creator, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(project.name)
  end

  it 'shows project details' do
    visit project_path(project)
    expect(page).to have_content(project.name)
    expect(page).to have_link('Edit')
    expect(page).to have_link('Edit permissions')
    expect(page).to have_button('Delete this project')
  end

  it 'lists the creator and owner' do
    visit project_path(project)
    expect(page).to have_content('Created by')
    expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
    expect(page).to have_content('Owned by')
    expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    #save_and_open_page
    fill_in 'project_name', with: 'test name'
    fill_in 'project[description]', with: 'description'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end

  it 'updates project when filling out form correctly' do
    visit edit_project_path(project)
    #save_and_open_page
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    expect(page).to have_content('test name')
  end

end

describe 'CRUD Projects as valid user with read permission', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as reader_user, scope: :user
  end

  it 'lists all projects' do
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).to have_content(project.name)
  end

  it 'shows project details' do
    visit project_path(project)
    expect(page).to have_content(project.name)
    expect(page).not_to have_link('Edit')
    expect(page).not_to have_link('Edit Permissions')
    expect(page).not_to have_link('Delete')
  end

  it 'lists the creator and owner' do
    visit project_path(project)
    expect(page).to have_content('Created by')
    expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
    expect(page).to have_content('Owned by')
    expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end


  it 'rejects access to update project' do
    visit edit_project_path(project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

end

describe 'CRUD Projects as valid user with no permissions', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as no_access_user, scope: :user
  end

  it 'lists all projects' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit projects_path
    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Projects')
    expect(page).not_to have_content(project.name)
  end

  it 'rejects access to show project details' do
    visit project_path(project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'creates new project when filling out form correctly' do
    visit new_project_path
    fill_in 'project[name]', with: 'test name'
    fill_in 'project[description]', with: 'description'
    attach_file('project[image]', 'public/images/user/user-512.png')
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('test name')
    expect(page).to have_content('Project was successfully created.')
  end

  it 'rejects access to edit project details' do
    visit edit_project_path(project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

end

describe 'Delete Projects as admin user', :type => :feature do

  create_entire_hierarchy

  before(:each) do
    login_as admin_user, scope: :user
  end

  it 'deletes a project' do
    visit project_path(project)
    expect(page).to have_button('Delete this project')
    expect { first(:button, 'Delete').click }.to change(Project, :count).by(-1)
  end
end

# describe 'CRUD Projects as unconfirmed user', :type => :feature do
#
#   create_entire_hierarchy
#
#   before(:each) do
#     login_as unconfirmed_user, scope: :user
#   end
#
#   it 'reject access to list all projects' do
#     visit projects_path
#     expect(current_path).to eq(projects_path)
#     expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
#   end
#
#   it 'rejects access to show project details' do
#     visit project_path(project)
#     expect(current_path).to eq(project_path(project))
#     expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
#   end
#
#   it 'rejects access to create a new project' do
#     visit new_project_path
#     expect(current_path).to eq(new_project_path)
#     expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
#
#   end
#
#   it 'rejects access to edit project details' do
#     visit edit_project_path(project)
#     expect(current_path).to eq(edit_project_path(project))
#     expect(page).to have_content(I18n.t('devise.failure.unconfirmed'))
#   end
#
# end

describe 'request project access', :type => :feature do

  create_entire_hierarchy

  before(:each) do

    login_as no_access_user, scope: :user
  end

  it 'sends emails when form filled out successfully' do
    ActionMailer::Base.deliveries.clear

    visit new_access_request_projects_path
    #save_and_open_page
    expect(current_path).to eq(new_access_request_projects_path)
    fill_in 'access_request[reason]', with: 'testing testing'
    select_by_value('access_request_projects', project.id)
    #page.select project.name, from: 'access_request[projects][]'
    click_button 'Submit request'

    expect(current_path).to eq(projects_path)
    expect(page).to have_content('Access request successfully submitted.')

    expect(ActionMailer::Base.deliveries.size).to eq(1)
    email = ActionMailer::Base.deliveries[0]
    expect(email).to have_content(project.name)
    expect(email).to have_content(project.creator.user_name)
    expect(email).to have_content(no_access_user.user_name)
  end

  it 'shows error when form not filled out correctly' do
    ActionMailer::Base.deliveries.clear

    visit new_access_request_projects_path
    #save_and_open_page
    expect(current_path).to eq(new_access_request_projects_path)
    #fill_in 'access_request[reason]', with: 'testing testing'
    select_by_value('access_request_projects', project.id)
    #page.select project.name, from: 'access_request[projects][]'
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
    #select_by_value('access_request_projects', project.id)
    #page.select project.name, from: 'access_request[projects][]'
    click_button 'Submit request'

    expect(current_path).to eq(new_access_request_projects_path)
    expect(page).to have_content('Please select projects and provide reason for access.')

    expect(ActionMailer::Base.deliveries.size).to eq(0)
  end
end

describe 'Project', type: :feature do
  create_entire_hierarchy

  context 'CRUD' do

    context 'for an admin user' do
      before(:each) do
        login_as admin_user, scope: :user
      end

      it 'lists all projects' do
        visit projects_path
        expect(current_path).to eq(projects_path)
        expect(page).to have_content('Projects')
        expect(page).to have_content(project.name)
      end

      it 'shows project details' do
        visit project_path(project)
        expect(page).to have_content(project.name)
        expect(page).to have_link('Edit this project')
        expect(page).to have_link('New site')
        expect(page).to have_link('Edit permissions')
        expect(page).to have_link('Assign sites')
        expect(page).to have_button('Delete this project')
      end

      it 'lists the creator and owner' do
        visit project_path(project)
        expect(page).to have_content('Created by')
        expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
        expect(page).to have_content('Owned by')
        expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
      end

      it 'creates new project when filling out form correctly' do
        visit new_project_path
        fill_in 'project_name', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
        expect(page).to have_content('Project was successfully created.')
      end

      it 'updates project when filling out form correctly' do
        visit edit_project_path(project)
        fill_in 'project[name]', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
      end

      it 'deletes a project' do
        visit project_path(project)
        expect(page).to have_button('Delete this project')
        expect { first(:button, 'Delete').click }.to change(Project, :count).by(-1)
      end
    end

    context 'for a project owner' do
      before(:each) do
        login_as owner_user, scope: :user
      end

      it 'lists all projects' do
        visit projects_path
        expect(current_path).to eq(projects_path)
        expect(page).to have_content('Projects')
        expect(page).to have_content(project.name)
      end

      it 'shows project details' do
        visit project_path(project)
        expect(page).to have_content(project.name)
        expect(page).to have_link('Edit this project')
        expect(page).to have_link('New site')
        expect(page).to have_link('Edit permissions')
        expect(page).not_to have_link('Assign sites')
        expect(page).to have_button('Delete this project')
      end

      it 'lists the creator and owner' do
        visit project_path(project)
        expect(page).to have_content('Created by')
        expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
        expect(page).to have_content('Owned by')
        expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
      end

      it 'creates new project when filling out form correctly' do
        visit new_project_path
        fill_in 'project_name', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
        expect(page).to have_content('Project was successfully created.')
      end

      it 'updates project when filling out form correctly' do
        visit edit_project_path(project)
        fill_in 'project[name]', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
      end

      it 'deletes a project' do
        visit project_path(project)
        expect(page).to have_button('Delete this project')
        expect { first(:button, 'Delete').click }.to change(Project, :count).by(-1)
      end
    end

    context 'for a user with writer access' do
      before(:each) do
        login_as writer_user, scope: :user
      end

      it 'lists all projects' do
        visit projects_path
        expect(current_path).to eq(projects_path)
        expect(page).to have_content('Projects')
        expect(page).to have_content(project.name)
      end

      it 'shows project details' do
        visit project_path(project)
        expect(page).to have_content(project.name)
        expect(page).not_to have_link('Edit Project')
        expect(page).not_to have_link('Add New Site')
        expect(page).not_to have_link('Edit Permissions')
        expect(page).not_to have_link('Edit Sites')
        expect(page).not_to have_link('Delete Project')
      end

      it 'lists the creator and owner' do
        visit project_path(project)
        expect(page).to have_content('Created by')
        expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
        expect(page).to have_content('Owned by')
        expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
      end

      it 'creates new project when filling out form correctly' do
        visit new_project_path
        fill_in 'project[name]', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
        expect(page).to have_content('Project was successfully created.')
      end

      it 'Fails to create new project when filling out form incomplete' do
        visit new_project_path
        click_button 'Submit'
        expect(page).to have_content('Please review the problems below:')
      end

      it 'rejects access to update project' do
        visit edit_project_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end

    end

    context 'for a user with read access' do
      before(:each) do
        login_as reader_user, scope: :user
      end

      it 'lists all projects' do
        visit projects_path
        expect(current_path).to eq(projects_path)
        expect(page).to have_content('Projects')
        expect(page).to have_content(project.name)
      end

      it 'shows project details' do
        visit project_path(project)
        expect(page).to have_content(project.name)
        expect(page).not_to have_link('Edit Project')
        expect(page).not_to have_link('Add New Site')
        expect(page).not_to have_link('Edit Permissions')
        expect(page).not_to have_link('Edit Sites')
        expect(page).not_to have_link('Delete Project')
      end

      it 'lists the creator and owner' do
        visit project_path(project)
        expect(page).to have_content('Created by')
        expect(page).to have_link(project.creator.user_name, user_account_path(project.creator))
        expect(page).to have_content('Owned by')
        expect(page).to have_link(owner_user.user_name, user_account_path(owner_user))
      end

      it 'creates new project when filling out form correctly' do
        visit new_project_path
        fill_in 'project[name]', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
        expect(page).to have_content('Project was successfully created.')
      end

      it 'rejects access to update project' do
        visit edit_project_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end
    end

    context 'for a user with no access' do
      before(:each) do
        login_as no_access_user, scope: :user
      end

      it 'lists all projects' do
        visit projects_path
        expect(current_path).to eq(projects_path)
        expect(page).to have_content('Projects')
        expect(page).not_to have_content(project.name)
      end

      it 'rejects access to show project details' do
        visit project_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end

      it 'creates new project when filling out form correctly' do
        visit new_project_path
        fill_in 'project[name]', with: 'test name'
        fill_in 'project[description]', with: 'description'
        attach_file('project[image]', 'public/images/user/user-512.png')
        click_button 'Submit'
        expect(page).to have_content('test name')
        expect(page).to have_content('Project was successfully created.')
      end

      it 'rejects access to edit project details' do
        visit edit_project_path(project)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
      end
    end
  end

  context 'request access' do
    before(:each) do
      login_as no_access_user, scope: :user
    end

    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit new_access_request_projects_path
      #save_and_open_page
      expect(current_path).to eq(new_access_request_projects_path)
      fill_in 'access_request[reason]', with: 'testing testing'
      select_by_value('access_request_projects', project.id)
      #page.select project.name, from: 'access_request[projects][]'
      click_button 'Submit request'

      expect(current_path).to eq(projects_path)
      expect(page).to have_content('Access request successfully submitted.')

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries[0]
      expect(email).to have_content(project.name)
      expect(email).to have_content(project.creator.user_name)
      expect(email).to have_content(no_access_user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit new_access_request_projects_path
      #save_and_open_page
      expect(current_path).to eq(new_access_request_projects_path)
      #fill_in 'access_request[reason]', with: 'testing testing'
      select_by_value('access_request_projects', project.id)
      #page.select project.name, from: 'access_request[projects][]'
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
      #select_by_value('access_request_projects', project.id)
      #page.select project.name, from: 'access_request[projects][]'
      click_button 'Submit request'

      expect(current_path).to eq(new_access_request_projects_path)
      expect(page).to have_content('Please select projects and provide reason for access.')

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

  end
end
