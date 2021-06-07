# frozen_string_literal: true



xdescribe 'checking reactions to errors', type: :feature do
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
      expect(page).to have_content('Not found Could not find the requested page.')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(404)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on routing error' do
      visit '/does_not_exist/42'
      expect(current_path).to eq('/does_not_exist/42')
      expect(page).to have_content('Not found Could not find the requested page.')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(404)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on record not found error' do
      visit '/test_exceptions?exception_class=ActiveRecord::RecordNotFound'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Not found Could not find the requested item.')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(404)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on item not found error' do
      visit '/test_exceptions?exception_class=CustomErrors::ItemNotFoundError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Could not find the requested item')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(404)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on record not unique error' do
      visit '/test_exceptions?exception_class=ActiveRecord::RecordNotUnique'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The item must be unique')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(409)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on unsupported media type error' do
      visit '/test_exceptions?exception_class=CustomErrors::UnsupportedMediaTypeError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The format of the request is not supported')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(415)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    # this test will cause a json response, since it is raising a not acceptable error
    # which means none of the acceptable response formats are supported by the server
    # so it defaults to json
    it 'displays the correct page on not acceptable error' do
      visit '/test_exceptions?exception_class=CustomErrors::NotAcceptableError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('None of the acceptable response formats are available')
      expect(page).to have_content('406')
      expect(page).to have_content('meta')
      expect(page.status_code).to eq(406)
      expect(response_headers['Content-Type']).to match %r{application/json}
    end

    it 'displays the correct page on unprocessable entity error' do
      visit '/test_exceptions?exception_class=CustomErrors::UnprocessableEntityError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The request could not be understood')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(422)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on AR bad request error' do
      visit '/test_exceptions?exception_class=ActionController::BadRequest'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The request was not valid')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(400)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on bad request error' do
      visit '/test_exceptions?exception_class=CustomErrors::BadRequestError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('The request was not valid')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(400)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    it 'displays the correct page on unauthorized error' do
      visit '/test_exceptions?exception_class=CanCan::AccessDenied'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('You need to log in or register before continuing')
      expect(page).to have_content('Unauthorized')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(401)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    context 'writer user' do
      create_entire_hierarchy

      it 'displays the correct page on forbidden error' do
        login_as no_access_user, scope: :user
        url = "/projects/#{project.id}"

        visit url
        expect(current_path).to eq(url)
        expect(page).to have_content(I18n.t('devise.failure.unauthorized'))
        expect(page).to have_content('Forbidden')
        expect(page).not_to have_content('::')
        expect(page.status_code).to eq(403)
        expect(response_headers['Content-Type']).to match %r{text/html}
      end
    end

    it 'displays the correct page on custom routing error' do
      visit '/test_exceptions?exception_class=CustomErrors::RoutingArgumentError'
      expect(current_path).to eq('/test_exceptions')
      expect(page).to have_content('Could not find the requested page')
      expect(page).not_to have_content('::')
      expect(page.status_code).to eq(404)
      expect(response_headers['Content-Type']).to match %r{text/html}
    end

    context 'displays the correct page when directly requested for' do
      it 'arbitrary error page' do
        visit '/errors/blah%20blah'
        expect(current_path).to eq('/errors/blah%20blah')
        expect(page).to have_content('Bad request')
        expect(page).to have_content('There was a problem with your request. Perhaps go back and try again?')
        expect(page).not_to have_content('::')
        expect(page.status_code).to eq(400)
        expect(response_headers['Content-Type']).to match %r{text/html}
      end

      it 'bad request' do
        visit '/errors/bad_request'
        expect(current_path).to eq('/errors/bad_request')
        expect(page).to have_content('Bad request')
        expect(page).to have_content('There was a problem with your request. Perhaps go back and try again?')
        expect(page).not_to have_content('::')
        expect(page.status_code).to eq(400)
        expect(response_headers['Content-Type']).to match %r{text/html}
      end

      it '400' do
        visit '/errors/400'
        expect(current_path).to eq('/errors/400')
        expect(page).to have_content('Bad request')
        expect(page).to have_content('There was a problem with your request. Perhaps go back and try again?')
        expect(page).not_to have_content('::')
        expect(page.status_code).to eq(400)
        expect(response_headers['Content-Type']).to match %r{text/html}
      end

      it '404' do
        visit '/errors/404'
        expect(current_path).to eq('/errors/404')
        expect(page).to have_content('Not found')
        expect(page).to have_content('Could not find the requested page.')
        expect(page).not_to have_content('::')
        expect(page.status_code).to eq(404)
        expect(response_headers['Content-Type']).to match %r{text/html}
      end
    end
  end
end
