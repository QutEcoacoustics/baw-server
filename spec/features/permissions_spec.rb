require 'spec_helper'

describe 'MANAGE Project Permissions as valid user with write permission', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    login_as @permission.user, scope: :user
  end

  it 'lists project permissions' do
    visit project_permissions_path(@permission.project)
    expect(page).to have_content('Permissions')
  end

  it 'updates project permissions' do
    permission_user = FactoryGirl.create(:user)
    visit project_permissions_path(@permission.project)
    expect(page).to have_checked_field("user_#{permission_user.id}_permissions_level_none")

    page.choose("user_#{permission_user.id}_permissions_level_reader")
    click_button 'Update Permissions'
    expect(page).to have_content('Permissions were successfully updated.')
    expect(page).to have_checked_field("user_#{permission_user.id}_permissions_level_reader")

    page.choose("user_#{permission_user.id}_permissions_level_writer")
    click_button 'Update Permissions'
    expect(page).to have_content('Permissions were successfully updated.')
    expect(page).to have_checked_field("user_#{permission_user.id}_permissions_level_writer")
  end

end

describe 'Deny Project Permissions as valid user with read permission only', :type => :feature do
  before(:each) do
    @creator_user = FactoryGirl.create(:user)
    @login_user = FactoryGirl.create(:user)
    @permission = FactoryGirl.create(:read_permission, creator: @creator_user, user: @login_user)
    login_as @login_user, scope: :user
  end

  it 'denies access to list project permissions' do
    visit project_permissions_path(@permission.project)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end


end