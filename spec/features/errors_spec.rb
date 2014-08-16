require 'spec_helper'

describe 'checking reactions to errors' do


  context 'production with exceptions_app' do
    around(:each) do |example|
      stored_request_local = Rails.application.config.consider_all_requests_local
      Rails.application.config.consider_all_requests_local = false

      stored_show_exceptions = Rails.application.config.action_dispatch.show_exceptions
      Rails.application.config.action_dispatch.show_exceptions = true
      example.run
      Rails.application.config.consider_all_requests_local = stored_request_local
      Rails.application.config.action_dispatch.show_exceptions = stored_show_exceptions
    end

    it 'displays the correct page on routing error' do
      visit '/does_not_exist'
      expect(current_path).to eq('/does_not_exist')
      expect(page).to have_content('Could not find the requested page.')
    end

    it 'displays the correct page on routing error' do
      visit '/does_not_exist/42'
      expect(current_path).to eq('/does_not_exist/42')
      expect(page).to have_content('Could not find the requested page.')
    end

    it 'displays the correct page on record not found error' do
      visit '/test_exceptions?exception_class=ActiveRecord::RecordNotFound'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Could not find the requested item.')
    end

    it 'displays the correct page on item not found error' do
      visit '/test_exceptions?exception_class=CustomErrors::ItemNotFoundError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Could not find the requested item.')
    end

    it 'displays the correct page on record not unique error' do
      visit '/test_exceptions?exception_class=ActiveRecord::RecordNotUnique'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The item must be unique.')
    end

    it 'displays the correct page on unsupported media type error' do
      visit '/test_exceptions?exception_class=CustomErrors::UnsupportedMediaTypeError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The format of the request is not supported.')
    end

    it 'displays the correct page on not acceptable error' do
      visit '/test_exceptions?exception_class=CustomErrors::NotAcceptableError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('None of the acceptable response formats are available.')
    end

    it 'displays the correct page on unprocessable entity error' do
      visit '/test_exceptions?exception_class=CustomErrors::UnprocessableEntityError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The request could not be understood.')
    end

    it 'displays the correct page on bad request error' do
      visit '/test_exceptions?exception_class=ActiveResource::BadRequest'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The request was not valid.')
    end

    it 'displays the correct page on access denied error' do
      visit '/test_exceptions?exception_class=CanCan::AccessDenied'
      expect(current_path).to eq('/')
      expect(page).to have_content('You need to sign in or sign up before continuing.')
    end

    it 'displays the correct page on custom routing error' do
      visit '/test_exceptions?exception_class=CustomErrors::RoutingArgumentError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Could not find the requested page.')
    end

  end

end