require 'spec_helper'

describe 'checking reactions to errors' do
  around(:each) do |example|
    Rails.application.config.consider_all_requests_local = false
    Rails.application.config.action_dispatch.show_exceptions = true
    example.run
    Rails.application.config.consider_all_requests_local = true
    Rails.application.config.action_dispatch.show_exceptions = false
  end

  context 'exceptions_app' do
    it 'displays the correct page on access denied error' do
      visit '/test_exceptions?exception_class=CanCan::AccessDenied'
      expect(current_path).to eq('/')
      page.should have_content('You need to sign in or sign up before continuing.')
    end

    it 'displays the correct page on argument error' do
      visit '/test_exceptions?exception_class=ArgumentError'
      expect(current_path).to eq('/test_exceptions')
      page.should have_content('there was a problem')
      page.should have_content("We've encountered a problem. We'll look into it.")
    end

    it 'displays the correct page on missing template error' do
      visit '/test_exceptions?exception_class=ActionView::MissingTemplate'
      expect(current_path).to eq('/test_exceptions')
      page.should have_content('there was a problem')
      page.should have_content("We've encountered a problem. We'll look into it.")
      end

    it 'displays the correct page on record not found error' do
      visit '/test_exceptions?exception_class=ActiveRecord::RecordNotFound'
      expect(current_path).to eq('/test_exceptions')
      page.should have_content('page not found')
      page.should have_content("The page you were looking for doesn't exist. You may have mistyped the address or the page may have moved.")
    end


    it 'displays the correct page on custom routing error' do
      visit '/test_exceptions?exception_class=CustomErrors::RoutingArgumentError'
      expect(current_path).to eq('/test_exceptions')
      page.should have_content('page not found')
      page.should have_content("The page you were looking for doesn't exist. You may have mistyped the address or the page may have moved.")
    end

  end

  context 'routing' do
    it 'displays the correct page on routing error' do
      visit '/does_not_exist'
      expect(current_path).to eq('/does_not_exist')
      page.should have_content('page not found')
      page.should have_content("The page you were looking for doesn't exist. You may have mistyped the address or the page may have moved.")
    end
  end


end