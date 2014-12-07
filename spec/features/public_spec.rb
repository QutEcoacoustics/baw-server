require 'spec_helper'

describe 'Website forms', :type => :feature do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  context 'contact us' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit contact_us_path
      expect(current_path).to eq(contact_us_path)
      fill_in 'data_class_contact_us[name]', with: 'name'
      fill_in 'data_class_contact_us[content]', with: 'testing testing'
      click_button 'Submit'

      expect(current_path).to eq(contact_us_path)
      expect(page).to have_content('we need more information, we will be in touch with you shortly')

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries[0]
      expect(email).to have_content('[Contact Us]')
      expect(email).to have_content('name')
      expect(email).to have_content('testing testing')
      expect(email).to have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit contact_us_path
      expect(current_path).to eq(contact_us_path)
      click_button 'Submit'

      expect(current_path).to eq(contact_us_path)
      expect(page).to have_content('Please review the problems below')
      expect(page).to have_content("can't be blank")

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end
  end

  context 'bug report' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit bug_report_path
      expect(current_path).to eq(bug_report_path)
      fill_in 'data_class_bug_report[description]', with: 'description-1-1-1-1'
      fill_in 'data_class_bug_report[content]', with: 'testing testing'
      click_button 'Submit'

      expect(current_path).to eq(bug_report_path)
      expect(page).to have_content('we will let you know if the problems you describe are resolved')

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries[0]
      expect(email).to have_content('[Bug Report]')
      expect(email).to have_content('description-1-1-1-1')
      expect(email).to have_content('testing testing')
      expect(email).to have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit bug_report_path
      expect(current_path).to eq(bug_report_path)
      click_button 'Submit'

      expect(current_path).to eq(bug_report_path)
      expect(page).to have_content('Please review the problems below')
      expect(page).to have_content("can't be blank")

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end
  end

  context 'data request' do
    it 'sends emails when form filled out successfully' do
      ActionMailer::Base.deliveries.clear

      visit data_request_path
      expect(current_path).to eq(data_request_path)
      fill_in 'data_class_data_request[email]', with: 'email@email.com'
      fill_in 'data_class_data_request[group]', with: 'description-1-1-1-1'
      select 'Non profit', from: 'data_class_data_request[group_type]'
      fill_in 'data_class_data_request[content]', with: 'testing testing'
      click_button 'Submit'

      expect(current_path).to eq(data_request_path)
      expect(page).to have_content('Your request was successfully submitted. We will be in contact shortly.')

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      email = ActionMailer::Base.deliveries[0]
      expect(email).to have_content('[Data Request]')
      expect(email).to have_content('description-1-1-1-1')
      expect(email).to have_content('testing testing')
      expect(email).to have_content('non_profit')
      expect(email).to have_content(@user.user_name)
    end

    it 'shows error when form not filled out correctly' do
      ActionMailer::Base.deliveries.clear

      visit data_request_path
      expect(current_path).to eq(data_request_path)
      click_button 'Submit'

      expect(current_path).to eq(data_request_path)
      expect(page).to have_content('Please review the problems below')
      expect(page).to have_content("can't be blank")

      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end
  end

  context 'website status' do
    it 'shows the Statistics page' do
      visit website_status_path
      expect(current_path).to eq(website_status_path)
      expect(page).to have_content('unique tags')
    end

    it 'shows the Statistics page' do
      visit status_path
      expect(current_path).to eq(status_path)
      expect(page).to have_content('bad')
    end
  end
end

describe 'public website forms', :type => :feature do
  context 'static pages' do
    it 'shows the ethics_statement page' do
      visit ethics_statement_path
      expect(current_path).to eq(ethics_statement_path)
      expect(page).to have_content('Ethics Statement')
    end

    it 'shows the credits page' do
      visit credits_path
      expect(current_path).to eq(credits_path)
      expect(page).to have_content('Credits')
    end

    it 'shows the disclaimers page' do
      visit disclaimers_path
      expect(current_path).to eq(disclaimers_path)
      expect(page).to have_content('without express or implied warranty')
    end
  end

  context 'website status' do
    it 'shows the Statistics page' do
      visit website_status_path
      expect(current_path).to eq(website_status_path)
      expect(page).to have_content('unique tags')
    end

    it 'shows the Statistics page' do
      visit status_path
      expect(current_path).to eq(status_path)
      expect(page).to have_content('bad')
    end
  end
end