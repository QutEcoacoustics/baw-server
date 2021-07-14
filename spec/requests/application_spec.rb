# frozen_string_literal: true



describe 'Common behaviour', { type: :request } do
  it '404 should return 404' do
    headers = {
      'Accept' => 'application/json'
    }

    get '/i_do_not_exist', params: nil, headers: headers

    expect(response).to have_http_status(404)
    expect(response.headers).to_not have_key('X-Error-Message')
    expect(response.content_type).to include('application/json')
    parsed_response = JSON.parse(response.body)
    expect(parsed_response['meta']['error']['details']).to eq('Could not find the requested page.')
  end

  it '404 should return 404 (png)' do
    headers = {
      'Accept' => 'image/png'
    }

    get '/images/apple-touch-icon-72x72.png', params: nil, headers: headers

    expect(response).to have_http_status(404)
    expect(response.body.length).to eq 0
    expect(response.headers).to_not have_key('X-Error-Message')
  end
end
