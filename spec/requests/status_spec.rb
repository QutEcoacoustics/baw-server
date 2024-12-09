# frozen_string_literal: true

describe '/status.json' do
  before do
    BawWorkers::Config.original_audio_helper.possible_dirs.each { |path|
      FileUtils.mkdir_p(path)
    }
  end

  it 'everything ok' do
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'good',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'Alive',
      batch_analysis: 'Connected'
    })
  end

  it 'timeout (storage)' do
    allow(AudioRecording).to receive(:check_storage) {
      # simulate timeout
      (1..120).each do |i|
        puts i
        sleep(0.25)
      end
      raise 'This should not happen'
    }
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: true,
      database: 'unknown',
      redis: 'unknown',
      storage: 'unknown',
      upload: 'unknown',
      batch_analysis: 'unknown'
    })
  end

  it 'redis cant connect' do
    allow(BawWorkers::Config.redis_communicator).to \
      receive(:ping)
      .and_raise(Redis::CannotConnectError, 'message')
    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'error: message',
      storage: '1 audio recording storage directory available.',
      upload: 'Alive',
      batch_analysis: 'Connected'
    })
  end

  it 'upload service, bad storage' do
    stub_request(:get, 'upload.test:8080/api/v2/status')
      .to_return(
        body: '{"data_provider":{"error": "error message"}}',
        status: 200,
        headers: { content_type: 'application/json' }
      )

    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'error message',
      batch_analysis: 'Connected'
    })
  end

  it 'upload service, somewhere in the middle error' do
    # error generated due to bad config in prod, but we didn't handle it well, hence the test
    stub_request(:get, 'upload.test:8080/api/v2/status')
      .to_return(body: "Client sent an HTTP request to an HTTPS server.\n", status: 400)

    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'Client sent an HTTP request to an HTTPS server.',
      batch_analysis: 'Connected'
    })
  end

  it 'upload service, time out' do
    stub_request(:get, 'upload.test:8080/api/v2/status')
      .to_timeout

    get '/status.json'

    expect_success
    expect(api_result).to match({
      status: 'bad',
      timed_out: false,
      database: true,
      redis: 'PONG',
      storage: '1 audio recording storage directory available.',
      upload: 'error: execution expired',
      batch_analysis: 'Connected'
    })
  end
end
