require 'rails_helper'

describe "User account actions", :type => :feature do
  # from: http://guides.rubyonrails.org/testing.html
  # The ActionMailer::Base.deliveries array is only reset automatically in
  # ActionMailer::TestCase tests. If you want to have a clean slate outside Action
  # Mailer tests, you can reset it manually with: ActionMailer::Base.deliveries.clear
  before { ActionMailer::Base.deliveries.clear }

  let(:last_email) { ActionMailer::Base.deliveries.last }



  context 'log in' do

    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: user.email
      fill_in 'Password', with: user.password
      click_button I18n.t('devise.shared.links.sign_in')

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: user.user_name
      fill_in 'Password', with: user.password
      click_button I18n.t('devise.shared.links.sign_in')

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

    it 'should fail when invalid' do
      user = FactoryGirl.create(:user)
      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: 'user name does not exist'
      fill_in 'Password', with: user.password
      click_button I18n.t('devise.shared.links.sign_in')

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content('Invalid login or password.')
    end

  end

  context 'sign up' do
    it 'should succeed with valid values' do
      #user = FactoryGirl.create(:user)
      user_name = 'tester_tester'
      email = 'test.email@example.com'
      password = 'password123'
      visit new_user_registration_url

      fill_in 'User name', with: user_name
      fill_in 'Password', with: password, match: :prefer_exact
      fill_in 'Confirm new password', with: password
      fill_in 'Email', with: email
      click_button I18n.t('devise.shared.links.sign_up')

      #expect(current_path).to eq(root_path)
      expect(page).to have_content('Welcome! You have signed up successfully.')
      expect(User.count).to eq(1)
      expect(User.first.user_name).to eq(user_name)
    end

    it 'should fail when invalid' do
      #user = FactoryGirl.create(:user)
      user_name = 'tester_tester!@'
      email = 'test.email@example.com'
      password = 'password123'
      visit new_user_registration_url

      fill_in 'User name', with: user_name
      fill_in 'Password', with: password, match: :prefer_exact
      fill_in 'Confirm new password', with: password
      fill_in 'Email', with: email
      click_button I18n.t('devise.shared.links.sign_up')

      #expect(current_path).to eq(root_path)
      expect(page).to have_content('Only letters, numbers, spaces ( ), underscores (_) and dashes (-) are valid')
      expect(User.count).to eq(0)
    end
  end

  context 'edit account info' do

    before(:each) do
      @old_password = 'old password'
      @user = FactoryGirl.create(:user, password: @old_password)
      login_as @user, scope: :user
    end

    it 'should succeed with valid values' do
      new_password = 'new password'
      new_email = 'test11123@example.com'
      new_user_name = 'test_name_1'

      visit edit_user_registration_path
      fill_in 'user_user_name', with: new_user_name
      fill_in 'user_email', with: new_email
      fill_in 'user[password]', with: new_password
      fill_in 'user[password_confirmation]', with: new_password
      fill_in 'user[current_password]', with: @old_password
      attach_file('user[image]', 'public/images/user/user_span1.png')
      click_button 'Update'

      expect(page).to have_content(new_user_name)
      expect(page).to have_content(I18n.t('devise.registrations.update_needs_confirmation'))
      expect(current_path).to eq(root_path)

      visit edit_user_registration_path
      #expect(page).to have_content('user_span1.png')
      expect(page.find('.user_image div img')['src']).to include('user_span1.png')
      expect(page).to have_content(new_user_name)
      expect(page).to have_content('Currently waiting confirmation for: '+new_email)

      logout

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: new_user_name
      fill_in 'Password', with: new_password
      click_button I18n.t('devise.shared.links.sign_in')

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

    it 'should fail when invalid' do
      new_password = 'new password'
      new_email = 'test11123@example.com'
      new_user_name = 'test_name_1'

      visit edit_user_registration_path
      fill_in 'user_user_name', with: new_user_name
      fill_in 'user_email', with: new_email
      fill_in 'user[password]', with: new_password
      fill_in 'user[password_confirmation]', with: new_password
      fill_in 'user[current_password]', with: @old_password + 'a'
      attach_file('user[image]', 'public/images/user/user_span1.png')
      click_button 'Update'

      expect(page).to have_content('(required) Current passwordis invalid')
      expect(current_path).to eq(user_registration_path)

      visit edit_user_registration_path
      expect(page).to_not have_content('user_span1.png')
      expect(page).to_not have_content(new_user_name)
      expect(page).to_not have_content('Currently waiting confirmation for: '+new_email)

      expect(page).to have_content(@user.user_name)
      expect(page).to_not have_content(@user.email)

      logout

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click

      expect(current_url).to eq(new_user_session_url)
      fill_in 'Login', with: @user.email
      fill_in 'Password', with: @old_password
      click_button I18n.t('devise.shared.links.sign_in')

      expect(current_path).to eq(root_path)
      expect(page).to have_content('Signed in successfully.')
    end

  end

  context 'resend unlock' do
    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click
      first(:link, I18n.t('devise.shared.links.unlock_account')).click

      expect(current_url).to eq(new_user_unlock_url)
      fill_in 'Login', with: user.user_name
      click_button 'Resend unlock instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content(I18n.t('devise.unlocks.send_paranoid_instructions'))
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('unlock your account')
    end

    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click
      first(:link, I18n.t('devise.shared.links.unlock_account')).click

      expect(current_url).to eq(new_user_unlock_url)
      fill_in 'Login', with: user.email
      click_button 'Resend unlock instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content(I18n.t('devise.unlocks.send_paranoid_instructions'))
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('unlock your account')
    end
  end

  context 'reset password' do
    it 'should succeed when using user_name' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click
      first(:link, I18n.t('devise.shared.links.reset_password')).click

      expect(current_url).to eq(new_user_password_url)
      fill_in 'Login', with: user.user_name
      click_button 'Send me reset password instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content(I18n.t('devise.passwords.send_paranoid_instructions'))
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('change your password')
    end
    it 'should succeed when using email' do
      user = FactoryGirl.create(:user)
      user.lock_access!

      visit root_url
      first(:link, I18n.t('devise.shared.links.sign_in')).click
      first(:link, I18n.t('devise.shared.links.reset_password')).click

      expect(current_url).to eq(new_user_password_url)
      fill_in 'Login', with: user.email
      click_button 'Send me reset password instructions'

      expect(current_path).to eq(new_user_session_path)
      expect(page).to have_content(I18n.t('devise.passwords.send_paranoid_instructions'))
      expect(last_email.to).to include(user.email)
      expect(last_email.body.to_s).to include('change your password')
    end

    it 'email is sent and password is changed successfully' do
      # create user and go to forgot password page
      user = FactoryGirl.create(:user)
      visit root_url
      find(:xpath, "/descendant::a[@href='/my_account/sign_in'][1]").click

      click_link I18n.t('devise.shared.links.reset_password')

      fill_in 'Login', with: user.email
      click_button 'Send me reset password instructions'

      # back to sign in page, use token from email to go to reset password page
      expect(current_path).to eq('/my_account/sign_in')
      expect(page).to have_content(I18n.t('devise.passwords.send_paranoid_instructions'))

      expect(last_email.to).to include(user.email)

      # extract token from mail body
      mail_body = last_email.body.to_s
      token = mail_body[/#{:reset_password.to_s}_token=([^"]+)/, 1]

      visit edit_user_password_path(reset_password_token: token) # http://stackoverflow.com/a/18262856/31567

      # fill in incorrectly
      #save_and_open_page
      fill_in "user_password", :with => "foobar"
      fill_in "user_password_confirmation", :with => "foobar1"
      find(:xpath, '/descendant::input[@type="submit"]').click

      expect(page).to have_content('Please review the problems below')
      expect(page).to have_content("doesn't match")

      # fill in correctly
      fill_in "user_password", :with => "foobar11"
      fill_in "user_password_confirmation", :with => "foobar11"
      find(:xpath, '/descendant::input[@type="submit"]').click
      expect(current_path).to eq('/')
      expect(page).to have_content('Your password was changed successfully. You are now signed in.')
    end

    it 'email is sent and password can be changed for restricted user name' do
      # create user and go to forgot password page
      user = FactoryGirl.build(:user, user_name: 'aDmin')
      user.save!(validate: false)

      visit root_url
      find(:xpath, "/descendant::a[@href='/my_account/sign_in'][1]").click

      click_link I18n.t('devise.shared.links.reset_password')

      fill_in 'Login', with: user.email
      click_button 'Send me reset password instructions'

      # back to sign in page, use token from email to go to reset password page
      expect(current_path).to eq('/my_account/sign_in')
      expect(page).to have_content(I18n.t('devise.passwords.send_paranoid_instructions'))

      expect(last_email.to).to include(user.email)

      # extract token from mail body
      mail_body = last_email.body.to_s
      token = mail_body[/#{:reset_password.to_s}_token=([^"]+)/, 1]

      visit edit_user_password_path(reset_password_token: token) # http://stackoverflow.com/a/18262856/31567

      # fill in incorrectly
      #save_and_open_page
      fill_in "user_password", :with => "foobar"
      fill_in "user_password_confirmation", :with => "foobar1"
      find(:xpath, '/descendant::input[@type="submit"]').click

      expect(page).to have_content('Please review the problems below')
      expect(page).to have_content("doesn't match")

      # fill in correctly
      fill_in "user_password", :with => "foobar11"
      fill_in "user_password_confirmation", :with => "foobar11"
      find(:xpath, '/descendant::input[@type="submit"]').click
      expect(current_path).to eq('/')
      expect(page).to have_content('Your password was changed successfully. You are now signed in.')
    end
  end

end


describe 'MANAGE User Accounts as admin user', :type => :feature do
  before(:each) do
    admin = FactoryGirl.create(:admin)
    login_as admin, scope: :user
  end

  it 'lists all users' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit user_accounts_path
    expect(page).to have_content('User List')
  end

  it 'shows user account details' do
    user = FactoryGirl.create(:user)
    FactoryGirl.create(:bookmark, creator: user)
    visit user_account_path(user)
    expect(page).to have_content(user.user_name)
  end

  it 'updates user_account when filling out form correctly' do
    user = FactoryGirl.create(:user)
    visit edit_user_account_path(user)
    fill_in 'user[user_name]', with: 'test name'
    fill_in 'user[email]', with: 'test@example.com'
    attach_file('user[image]', 'public/images/user/user-512.png')
    click_button 'Update User'
    expect(page).to have_content('test name')
  end

  it 'cannot delete account' do
    FactoryGirl.create(:user)
    visit user_accounts_path
    expect(page).not_to have_content('Cancel my account')
  end

  it 'provides link to Projects Sites Bookmarks Annotations Comments' do
    user = FactoryGirl.create(:user)
    visit user_account_path(user)
    expect(page).to have_content('Their Projects Their Sites Their Bookmarks Their Annotations Their Comments')
  end

  it 'lists user\'s projects' do
    user = FactoryGirl.create(:user)
    project = FactoryGirl.create(:project)
    permission = FactoryGirl.create(:permission, user_id: user.id, project_id: project.id)
    visit projects_user_account_path(user)
    expect(page).to have_content('Project Sites Permission')
    expect(page).to have_content(project.name)
  end
end

describe 'MANAGE User Accounts as user', :type => :feature do
  before(:each) do
    @user = FactoryGirl.create(:user)
    login_as @user, scope: :user
  end

  let(:other_user){ FactoryGirl.create(:user)}

  it 'denies access' do
    visit user_accounts_path
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit edit_user_account_path(other_user)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end

  it 'shows user account details' do
    visit user_account_path(other_user)
    expect(page).to have_content(other_user.user_name)
  end

  context 'links available viewing other user page' do
      it 'should not link to projects' do
        visit user_account_path(other_user)
        expect(find('nav[role=navigation]')).to_not have_content('Projects')
      end
      it 'should not link to sites' do
        visit user_account_path(other_user)
        expect(find('nav[role=navigation]')).to_not have_content('Sites')
      end
      it 'should not link to bookmarks' do
        visit user_account_path(other_user)
        expect(find('nav[role=navigation]')).to_not have_content('Bookmarks')
      end
      it 'should not link to annotations' do
        visit user_account_path(other_user)
        expect(find('nav[role=navigation]')).to_not have_content('Annotations')
      end
      it 'should not link to comments' do
        visit user_account_path(other_user)
        expect(find('nav[role=navigation]')).to_not have_content('Comments')
      end
  end

  context 'links available viewing current user page' do

    it 'should link to projects' do
      visit my_account_path
      expect(find('nav[role=navigation]')).to have_content('Projects')
      click_link 'My Projects'
      expect(current_path).to eq(projects_user_account_path(@user))
    end
    it 'should link to sites' do
      visit my_account_path
      expect(find('nav[role=navigation]')).to have_content('Sites')
      click_link 'My Sites'
      expect(current_path).to eq(sites_user_account_path(@user))
    end
    it 'should link to bookmarks' do
      visit my_account_path
      expect(find('nav[role=navigation]')).to have_content('Bookmarks')
      click_link 'My Bookmarks'
      expect(current_path).to eq(bookmarks_user_account_path(@user))
    end
    it 'should link to annotations' do
      visit my_account_path
      expect(find('nav[role=navigation]')).to have_content('Annotations')
      click_link 'My Annotations'
      expect(current_path).to eq(audio_events_user_account_path(@user))
    end
    it 'should link to comments' do
      visit my_account_path
      expect(find('nav[role=navigation]')).to have_content('Comments')
      click_link 'My Comments'
      expect(current_path).to eq(audio_event_comments_user_account_path(@user))
    end
  end

  it 'denies access to user projects page' do
    user = FactoryGirl.create(:user)
    visit projects_user_account_path(user)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end

describe 'User profile pages' do
  before(:each) do
    @user = FactoryGirl.create(:user)
    login_as @user, scope: :user
  end

  it 'downloads csv file successfully' do
    visit my_account_path
    expect(page).to have_content("Annotations you've created")
    click_link("Annotations you've created")

    expected_url = "#{data_request_url}?annotation_download[user_id]=#{@user.id}"

    expect(current_url).to eq(expected_url)
    expect(page).to have_content("The CSV file containing annotations for #{@user.user_name} will download shortly.")

    click_link('here')

    expected_url = download_user_audio_events_url(@user)
    expect(current_url).to eq(expected_url)

    expect(page).to have_content('audio_event_id, audio_recording_id, audio_recording_uuid, audio_recording_start_date_utc, audio_recording_start_time_utc, audio_recording_start_datetime_utc, event_created_at_date_utc, event_created_at_time_utc, event_created_at_datetime_utc, projects, site_id, site_name, event_start_date_utc, event_start_time_utc, event_start_datetime_utc, event_start_seconds, event_end_seconds, event_duration_seconds, low_frequency_hertz, high_frequency_hertz, is_reference, created_by, updated_by, common_name_tags, common_name_tag_ids, species_name_tags, species_name_tag_ids, other_tags, other_tag_ids, listen_url, library_url')

    expect(page.response_headers['Content-Disposition']).to include('attachment; filename="')
    expect(page.response_headers['Content-Type']).to eq('text/csv')
  end

  # it 'should link to user saved searches for current user page' do
  #   visit my_account_path
  #   click_link 'Saved Searches'
  #   expect(current_path).to eq(saved_searches_user_account_path(@user))
  # end
  #
  # it 'should link to user analysis jobs for current user page' do
  #   visit my_account_path
  #   click_link 'Analysis Jobs'
  #   expect(current_path).to eq(analysis_jobs_user_account_path(@user))
  # end
end
