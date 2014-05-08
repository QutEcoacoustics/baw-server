require 'spec_helper'

describe 'Website forms' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  context 'contact us' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit contact_us_path
      current_path.should eq(contact_us_path)
      fill_in 'contact_us[name]', with: 'name'
      fill_in 'contact_us[content]', with: 'testing testing'
      click_button 'Submit'

      current_path.should eq(contact_us_path)
      page.should have_content('we need more information, we will be in touch with you shortly')

      ActionMailer::Base.deliveries.size.should eq(1)
      email = ActionMailer::Base.deliveries[0]
      email.should have_content('[Contact Us]')
      email.should have_content('name')
      email.should have_content('testing testing')
      email.should have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit contact_us_path
      current_path.should eq(contact_us_path)
      click_button 'Submit'

      current_path.should eq(contact_us_path)
      page.should have_content('Please review the problems below')
      page.should have_content("can't be blank")

      ActionMailer::Base.deliveries.size.should eq(0)
    end
  end

  context 'bug report' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit bug_report_path
      current_path.should eq(bug_report_path)
      fill_in 'bug_report[description]', with: 'description-1-1-1-1'
      fill_in 'bug_report[content]', with: 'testing testing'
      click_button 'Submit'

      current_path.should eq(bug_report_path)
      page.should have_content('we will let you know if the problems you describe are resolved')

      ActionMailer::Base.deliveries.size.should eq(1)
      email = ActionMailer::Base.deliveries[0]
      email.should have_content('[Bug Report]')
      email.should have_content('description-1-1-1-1')
      email.should have_content('testing testing')
      email.should have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit bug_report_path
      current_path.should eq(bug_report_path)
      click_button 'Submit'

      current_path.should eq(bug_report_path)
      page.should have_content('Please review the problems below')
      page.should have_content("can't be blank")

      ActionMailer::Base.deliveries.size.should eq(0)
    end
  end

  context 'data request' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit data_request_path
      current_path.should eq(data_request_path)
      fill_in 'data_request[email]', with: 'email@email.com'
      fill_in 'data_request[group]', with: 'description-1-1-1-1'
      select 'Non profit', from: 'data_request[group_type]'
      fill_in 'data_request[content]', with: 'testing testing'
      click_button 'Submit'

      current_path.should eq(data_request_path)
      page.should have_content('Your request was successfully submitted. We will be in contact shortly.')

      ActionMailer::Base.deliveries.size.should eq(1)
      email = ActionMailer::Base.deliveries[0]
      email.should have_content('[Data Request]')
      email.should have_content('description-1-1-1-1')
      email.should have_content('testing testing')
      email.should have_content('non_profit')
      email.should have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit data_request_path
      current_path.should eq(data_request_path)
      click_button 'Submit'

      current_path.should eq(data_request_path)
      page.should have_content('Please review the problems below')
      page.should have_content("can't be blank")

      ActionMailer::Base.deliveries.size.should eq(0)
    end
  end
end