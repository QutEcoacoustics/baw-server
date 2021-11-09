# frozen_string_literal: true

describe 'WebServerHelper::ExampleGroup', type: :request do
  extend WebServerHelper::ExampleGroup
  let(:origin) { "http://#{Settings.api.host}:#{Settings.api.port}" }
  let(:url) { "#{origin}/status.json" }

  def port_open?
    begin
      TCPSocket.new('127.0.0.1', Settings.api.port)
    rescue Errno::ECONNREFUSED
      return false
    end
    true
  end

  context 'when starting a web server,' do
    around do |example|
      expect(port_open?).to eq false
      example.call
      expect(port_open?).to eq false
    end

    context 'when times out' do
      around do |example|
        example.call

        raise 'Timeout did not trigger, this should not happen'
      rescue Timeout::Error => e
        logger.info('suppressing expected timeout', exception: e)
        true
      end

      context 'with scoped nesting' do
        expose_app_as_web_server
        it 'raises a timeout error', web_server_timeout: 1.5 do
          count = 0
          sleep 1 until (count += 1) > 4
        end
      end
    end

    context 'when accepting requests' do
      expose_app_as_web_server

      it 'checks the port is open' do
        expect(port_open?).to eq true
      end

      it 'via net::HTTP' do
        response = Net::HTTP.get_response(URI(url))
        expect(response.code).to eq '200'
      end

      it 'via faraday' do
        response = Faraday.get(url)
        expect(response.status).to eq 200
      end

      it 'via popen3' do
        stdout, stderr, status = Open3.capture3("curl '#{url}'")
        # you have to read these streams or else we don't trigger the fiber reentry
        logger.info(stdout)
        logger.info(stderr)

        expect(status.exitstatus).to eq 0
      end

      # Can't work this out, known bugs exist with async and ruby <3.3. Try again later
      # results in:
      #  Errno::EBADF:
      #    Bad file descriptor - epoll_ctl(process_wait)
      xit 'via system' do
        # Won't use the scheduler:
        system("curl '#{url}'")

        expect($CHILD_STATUS.exitstatus).to eq 0
      end

      # Can't work this out, known bugs exist with async and ruby <3.3. Try again later
      xit 'via Kernel.`' do
        _ = `curl '#{url}'`
        expect($CHILD_STATUS.exitstatus).to eq 0
      end
    end
  end

  it 'has stopped the server' do
    expect(port_open?).to eq false
  end

  context 'when accessing test state' do
    prepare_users
    prepare_dataset
    create_anon_hierarchy
    expose_app_as_web_server
    it 'works for database records' do
      all = AudioRecording.all.pick(:id)

      response = Faraday.get("#{origin}/audio_recordings")
      decoded = JSON.parse(response.body, { symbolize_names: true })

      expect(response.status).to eq 200
      expect(decoded[:data].map { |x| x[:id] }).to contain_exactly(all)
    end

    it 'can mock any instance of a class, and external http requests will work' do
      allow_any_instance_of(AudioRecording).to receive(:id).and_return(123_456)

      response = Faraday.get("#{origin}/audio_recordings")
      decoded = JSON.parse(response.body, { symbolize_names: true })

      expect(response.status).to eq 200
      expect(decoded[:data].map { |x| x[:id] }).to contain_exactly(123_456)
    end
  end
end
