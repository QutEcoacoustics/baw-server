# frozen_string_literal: true

describe Internal::SftpgoController do
  let(:payload) {
    <<~JSON
      {"action":"upload","username":"user","path":"/srv/sftpgo/data/user/test.R","virtual_path":"/test.R","fs_provider":0,"status":1,"protocol":"SFTP","ip":"172.18.0.1","session_id":"SFTP_e854785960bc21d240cd50b8f94c1452e185d5182aecd08f3b99a64d6876395a_1","timestamp":1649845689143321984}
    JSON
  }

  let(:headers) {
    {
      'ACCEPT' => 'application/json',
      'CONTENT_TYPE' => 'application/json',
      'REMOTE_ADDR' => '172.0.0.1'
    }.freeze
  }

  it 'accepts payloads from IPs in the allow list' do
    post '/internal/sftpgo/hook', params: payload, headers: headers

    expect_success
    expect_empty_body
  end

  it 'rejects payloads from IPs in the allow list' do
    remote_headers = { **headers, 'REMOTE_ADDR' => '173.0.0.1' }

    post '/internal/sftpgo/hook', params: payload, headers: remote_headers

    expect(response).to have_http_status(:unauthorized)
    expect_error(:unauthorized, 'You need to log in or register before continuing.')
  end
end
