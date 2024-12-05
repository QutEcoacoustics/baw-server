# frozen_string_literal: true

xdescribe 'MANAGE Scripts as admin user' do
  before do
    admin = create(:admin)
    @script = create(:script)
    login_as admin, scope: :user
  end

  it 'lists all scripts' do
    # Run the generator again with the --webrat flag if you want to use webrat methods/matchers
    visit admin_scripts_path
    expect(page).to have_content('Scripts')
  end

  it 'shows script account details' do
    script = create(:script)
    visit admin_script_path(script)
    expect(page).to have_content(script.name)
  end

  it 'creates script when filling out form correctly' do
    visit new_admin_script_path
    fill_in 'script[name]', with: 'test name'
    fill_in 'script[description]', with: 'description'
    fill_in 'script[analysis_identifier]', with: 'analysis.identifier'
    fill_in 'script[version]', with: '0.1'

    fill_in 'script[executable_command]', with: 'command'
    fill_in 'script[executable_settings]', with: 'settings'
    fill_in 'script[executable_settings_media_type]', with: 'text/plain'

    click_button 'Submit'
    expect(page).not_to have_content('Please review the problems below')
    expect(page).to have_content('test name')
  end

  it 'Fails to create new script when filling out form incomplete' do
    visit new_admin_script_path
    click_button 'Submit'
    #save_and_open_page
    expect(page).to have_content('Please review the problems below:')
  end

  it 'updates script when filling out form correctly' do
    script = create(:script)
    new_script_version = (script.version + 1).to_s
    visit edit_admin_script_path(script)
    fill_in 'script[name]', with: 'test name'
    fill_in 'script[description]', with: 'description'
    fill_in 'script[analysis_identifier]', with: 'analysis.identifier'
    fill_in 'script[version]', with: new_script_version

    fill_in 'script[executable_command]', with: 'command'
    fill_in 'script[executable_settings]', with: 'settings'
    fill_in 'script[executable_settings_media_type]', with: 'application/javascript'

    click_button 'Submit'
    expect(page).not_to have_content('Please review the problems below')
    expect(page).to have_content('test name')
    expect(page).to have_content(new_script_version)
    expect(page).to have_content('application/javascript')
  end

  it 'shows script account details' do
    script = create(:script)
    visit edit_admin_script_path(script)
    expect(page).to have_content(script.name)
  end

  #it 'deletes a script' do
  #  FactoryBot.create(:script)
  #  visit scripts_path
  #  expect { first(:link, 'Delete').click }.to change(Script, :count).by(-1)
  #end
end

xdescribe 'MANAGE Scripts as user' do
  before do
    user = create(:user)
    login_as user, scope: :user
  end

  it 'denies access' do
    script = create(:script)
    visit admin_scripts_path
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit admin_script_path(script)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit new_admin_script_path
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
    visit edit_admin_script_path(script)
    expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
  end
end
