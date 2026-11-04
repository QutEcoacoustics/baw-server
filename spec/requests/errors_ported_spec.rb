# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/errors_spec.rb.

describe 'Error response contracts (ported)' do
  render_error_responses

  ['/does_not_exist', '/does_not_exist/42'].each do |path|
    it "identifies the original route for #{path}" do
      get path, headers: { 'ACCEPT' => 'application/json' }

      expect(response).to have_http_status(:not_found)
      expect(api_result.dig(:meta, :error, :info)).to include(original_route: path.delete_prefix('/'))
    end
  end

  # RecordNotFound, UnprocessableEntityError and RoutingArgumentError mappings are
  # covered through real endpoints in sites_spec.rb, analysis_jobs/invalid_requests_spec.rb
  # and harvest/harvest_spec.rb respectively.
  {
    'CustomErrors::ItemNotFoundError' => [:not_found, 'Could not find the requested item'],
    'CustomErrors::UnsupportedMediaTypeError' => [
      :unsupported_media_type, 'The format of the request is not supported'
    ],
    'CustomErrors::NotAcceptableError' => [:not_acceptable, 'None of the acceptable response formats are available'],
    'ActionController::BadRequest' => [:bad_request, 'The request was not valid.'],
    'CustomErrors::FilterArgumentError' => [:bad_request, 'Filter parameters were not valid']
  }.each do |exception_class, (status, details)|
    it "renders #{exception_class} with its mapped status and message" do
      get '/test_exceptions', params: { exception_class: },
        headers: { 'ACCEPT' => 'application/json' }

      expect_error(status, a_string_starting_with(details))

      if ['CustomErrors::UnsupportedMediaTypeError', 'CustomErrors::NotAcceptableError'].include?(exception_class)
        expect(api_result.dig(:meta, :error, :info)).to have_key(:available_formats)
      end
    end
  end

  it 'includes authentication recovery links for unauthenticated access failures' do
    get '/test_exceptions', params: { exception_class: 'CanCan::AccessDenied' },
      headers: { 'ACCEPT' => 'application/json' }

    expect_error(:unauthorized, I18n.t('devise.failure.unauthenticated'))
    expect(response.parsed_body.dig('meta', 'error', 'links')).to include(
      I18n.t('devise.sessions.new.sign_in') => new_user_session_path,
      I18n.t('devise.registrations.new.sign_up') => new_user_registration_path,
      I18n.t('devise.shared.links.confirm_account') => new_user_confirmation_path
    )
  end

  context 'when an audio tool fails' do
    pause_all_jobs

    it 'renders an internal server error with the audio failure details' do
      get '/test_exceptions', params: { exception_class: 'BawAudioTools::Exceptions::AudioToolError' },
        headers: { 'ACCEPT' => 'application/json' }

      expect_error(:internal_server_error, 'Audio generation failed: Purposeful exception raised for testing.')
    end

    it 'returns error headers without a body for HEAD and sends the exception notification asynchronously' do
      head '/test_exceptions', params: { exception_class: 'BawAudioTools::Exceptions::AudioToolError' },
        headers: { 'ACCEPT' => 'application/json' }

      expect(response).to have_http_status(:internal_server_error)
      expect(response.body).to be_empty
      expect(response.headers['X-Error-Type']).to eq('Baw Audio Tools/Exceptions/Audio Tool Error')
      expect_and_deliver_async_email(of_class: BawWorkers::Jobs::Mail::DeliverRawEmailJob)
    end
  end
end
