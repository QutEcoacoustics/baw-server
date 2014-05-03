require 'spec_helper'

describe 'contact us feedback mailer' do
  before(:each) do
    @permission = FactoryGirl.create(:write_permission)
    @user = FactoryGirl.create(:user) # creating new user with no permission to login
    login_as @user, scope: :user
  end

  it 'sends emails when form filled out successfully' do
    ActionMailer::Base.deliveries.clear

    visit contact_us_path
    current_path.should eq(contact_us_path)
    fill_in 'contact_us[content]', with: 'testing testing'
    click_button 'Submit'

    current_path.should eq(contact_us_path)
    page.should have_content('Thank you for contacting us. If you')

    ActionMailer::Base.deliveries.size.should eq(1)
    email = ActionMailer::Base.deliveries[0]
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