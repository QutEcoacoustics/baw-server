require 'spec_helper'

describe "User account actions" do
  # from: http://guides.rubyonrails.org/testing.html
  # The ActionMailer::Base.deliveries array is only reset automatically in
  # ActionMailer::TestCase tests. If you want to have a clean slate outside Action
  # Mailer tests, you can reset it manually with: ActionMailer::Base.deliveries.clear
  before { ActionMailer::Base.deliveries.clear }

  let(:last_email){ ActionMailer::Base.deliveries.last }

  it "emails user when requesting password reset" do
    # create user and go to forgot password page
    user = FactoryGirl.create(:user)
    visit root_url
    find(:xpath, "/descendant::a[@href='/my_account/sign_in'][1]").click

    click_link "Forgot password"

    fill_in 'Login', with: user.email
    click_button "Send me reset password instructions"

    # back to sign in page, use token from email to go to reset password page
    current_path.should eq('/my_account/sign_in')
    page.should have_content("You will receive an email with instructions about how to reset your password in a few minutes.")

    last_email.to.should include(user.email)

    # extract token from mail body
    mail_body = last_email.body.to_s
    token = mail_body[/#{:reset_password.to_s}_token=([^"]+)/, 1]

    visit edit_user_password_path(reset_password_token: token) # http://stackoverflow.com/a/18262856/31567

    # fill in incorrectly
    fill_in "user_password", :with => "foobar"
    fill_in "user_password_confirmation", :with => "foobar1"
    find(:xpath, '/descendant::input[@type="submit"]').click

    page.should have_content('Please review the problems below')
    page.should have_content("doesn't match confirmation")

    # fill in correctly
    fill_in "user_password", :with => "foobar11"
    fill_in "user_password_confirmation", :with => "foobar11"
    find(:xpath, '/descendant::input[@type="submit"]').click
    current_path.should eq('/')
    page.should have_content('Your password was changed successfully. You are now signed in.')
  end

  context 'log in' do

    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, 'Login').click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: user.email
      fill_in 'Password', with: user.password
      click_button 'Sign in'

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, 'Login').click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: user.user_name
      fill_in 'Password', with: user.password
      click_button 'Sign in'

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

    it 'should fail when invalid' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, 'Login').click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: 'user name does not exist'
      fill_in 'Password', with: user.password
      click_button 'Sign in'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('Invalid login or password.')
    end

  end

  context 'resend unlock' do
    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, 'Login').click
      first(:link, 'Resend unlock').click

      expect(current_url).to eq(new_user_unlock_url)
      fill_in 'Login', with: user.user_name
      click_button 'Resend unlock instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('You will receive an email with instructions about how to unlock your account in a few minutes.')
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('unlock your account')
    end

    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, 'Login').click
      first(:link, 'Resend unlock').click

      expect(current_url).to eq(new_user_unlock_url)
      fill_in 'Login', with: user.email
      click_button 'Resend unlock instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('You will receive an email with instructions about how to unlock your account in a few minutes.')
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('unlock your account')
    end
  end

  context 'reset password' do
    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, 'Login').click
      first(:link, 'Forgot password').click

      expect(current_url).to eq(new_user_password_url)
      fill_in 'Login', with: user.user_name
      click_button 'Send me reset password instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('email with instructions about how to reset your password')
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('change your password')
    end
    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, 'Login').click
      first(:link, 'Forgot password').click

      expect(current_url).to eq(new_user_password_url)
      fill_in 'Login', with: user.email
      click_button 'Send me reset password instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('email with instructions about how to reset your password')
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('change your password')
    end
  end

end


describe 'MANAGE User Accounts as admin user' do
  before(:each) do
    admin = FactoryGirl.create(:admin)
    login_as admin, scope: :user
  end

  it 'lists all users' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit user_accounts_path
    page.should have_content('User Accounts')
  end

  it 'shows user account details' do
    user = FactoryGirl.create(:user)
    FactoryGirl.create(:bookmark, creator: user)
    visit user_account_path(user)
    page.should have_content(user.user_name)
  end

  it 'updates user_account when filling out form correctly' do
    user = FactoryGirl.create(:user)
    visit edit_user_account_path(user)
    fill_in 'user[user_name]', with: 'test name'
    fill_in 'user[email]', with: 'test@example.com'
    attach_file('user[image]', 'public/images/user/user-512.png')
    click_button 'Update User'
    page.should have_content('test name')
  end

  it 'cannot delete account' do
    FactoryGirl.create(:user)
    visit user_accounts_path
    expect(page).not_to have_content('Cancel my account')
  end

  it 'provides link to Projects Bookmarks Annotations Comments' do
    user = FactoryGirl.create(:user)
    visit user_account_path(user)
    expect(page).to have_content('Projects Bookmarks Annotations Comments')
  end

  it 'lists user\'s projects' do
    user = FactoryGirl.create(:user)
    project = FactoryGirl.create(:project)
    permission = FactoryGirl.create(:permission, user_id: user.id, project_id: project.id)
    visit projects_user_account_path(user)
    page.should have_content('Number of Sites')
    page.should have_content(project.name)
  end
end

describe 'MANAGE User Accounts as user' do
  before(:each) do
    user = FactoryGirl.create(:user)
    login_as user, scope: :user
  end

  it 'denies access' do
    user = FactoryGirl.create(:user)
    visit user_accounts_path
    page.should have_content(I18n.t('devise.failure.unauthorized'))
    visit edit_user_account_path(user)
    page.should have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'shows user account details' do
    user = FactoryGirl.create(:user)
    FactoryGirl.create(:bookmark, creator: user)
    visit user_account_path(user)
    page.should have_content(user.user_name)
  end

  it 'should not link to user comments for other user page' do
    user = FactoryGirl.create(:user)
    visit user_account_path(user)
    expect(find('.nav-list')).to_not have_content('Comments')
  end

  it 'should not link to user bookmarks for other user page' do
    user = FactoryGirl.create(:user)
    visit user_account_path(user)
    expect(find('.nav-list')).to_not have_content('Bookmarks')
  end

  it 'should not link to user projects for other user page' do
    user = FactoryGirl.create(:user)
    visit user_account_path(user)
    expect(find('.nav-list')).to_not have_content('Projects')
  end

  it 'should link to user comments for current user page' do
    visit my_account_path
    expect(find('.nav-list')).to have_content('Comments')
  end

  it 'should link to user bookmarks for current user page' do
    visit my_account_path
    expect(find('.nav-list')).to have_content('Bookmarks')
  end

  it 'should link to user projects for current user page' do
    visit my_account_path
    expect(find('.nav-list')).to have_content('Projects')
  end

  it 'should link to user projects for current user page' do
    visit my_account_path
    expect(find('.nav-list')).to have_content('Annotations')
  end

  it 'denies access to user projects page' do
    user = FactoryGirl.create(:user)
    visit projects_user_account_path(user)
    page.should have_content(I18n.t('devise.failure.unauthorized'))
  end
end
