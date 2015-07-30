require 'spec_helper'

describe 'MANAGE Scripts as admin user', :type => :feature do 
  before(:each) do
    admin = FactoryGirl.create(:admin)
    @script = FactoryGirl.create(:script)
    login_as admin, scope: :user
  end

  it 'lists all scripts' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit scripts_path
    expect(page).to have_content('Scripts')
  end

  it 'shows script account details' do
    script = FactoryGirl.create(:script)
    visit script_path(script)
    expect(page).to have_content(script.name)
  end

  it 'creates script when filling out form correctly' do
    visit new_script_path
    fill_in 'script[name]', with: 'test name'
    fill_in 'script[description]', with: 'description'
    fill_in 'script[notes]', with: 'notes'
    fill_in 'script[analysis_identifier]', with: 'analysis.identifier'
    fill_in 'script[version]', with: '0.1'

    attach_file('script[settings_file]', 'public/files/script/settings_file.txt')
    attach_file('script[data_file]', 'public/files/script/settings_file.txt')

    click_button 'Submit'
    expect(page).to have_content('test name')
  end

  it 'Fails to create new script when filling out form incomplete' do
    visit new_script_path
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates script when filling out form correctly' do
    script = FactoryGirl.create(:script)
    visit edit_script_path(script)
    fill_in 'script[name]', with: 'test name'
    fill_in 'script[description]', with: 'description'
    fill_in 'script[notes]', with: 'notes'
    fill_in 'script[analysis_identifier]', with: 'analysis.identifier'
    fill_in 'script[version]', with: '1.1'

    attach_file('script[settings_file]', 'public/files/script/settings_file.txt')
    attach_file('script[data_file]', 'public/files/script/settings_file.txt')

    click_button 'Submit'
    expect(page).to have_content('test name')
  end

  it 'shows script account details' do
    script = FactoryGirl.create(:script)
    visit edit_script_path(script)
    expect(page).to have_content(script.name)
  end

  #it 'deletes a script' do
  #  FactoryGirl.create(:script)
  #  visit scripts_path
  #  expect { first(:link, 'Delete').click }.to change(Script, :count).by(-1)
  #end
end

describe 'MANAGE Scripts as user', :type => :feature do
  before(:each) do
    user = FactoryGirl.create(:user)
      login_as user, scope: :user
  end

  it 'denies access' do
    script = FactoryGirl.create(:script)
    visit scripts_path
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit script_path(script)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit new_script_path
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit edit_script_path(script)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end


end
