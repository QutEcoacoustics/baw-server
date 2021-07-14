# frozen_string_literal: true

describe BawWorkers::Jobs::AudioCheck::Action do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  # we want to control the execution of jobs for this set of tests,
  # so change the queue name so the test worker does not
  # automatically process the jobs
  before do
    default_queue = Settings.actions.audio_check.queue

    allow(Settings.actions.audio_check).to receive(:queue).and_return("#{default_queue}_manual_tick")

    # cleanup resque queues before each test
    BawWorkers::ResqueApi.clear_queue(default_queue)
    BawWorkers::ResqueApi.clear_queue(Settings.actions.audio_check.queue)
    Resque::Plugins::Status::Hash.clear
  end

  let(:queue_name) { Settings.actions.audio_check.queue }

  let(:audio_file_check) {
    BawWorkers::Jobs::AudioCheck::WorkHelper.new(
      BawWorkers::Config.logger_worker,
      BawWorkers::Config.file_info,
      BawWorkers::Config.api_communicator
    )
  }

  # when args are retreived from redis, they are all strings.
  let(:test_params) {
    {
      'id' => 5,
      'uuid' => '7bb0c719-143f-4373-a724-8138219006d9',
      'recorded_date' => '2010-02-23 20:42:00Z',
      'duration_seconds' => audio_file_mono_duration_seconds.to_s,
      'sample_rate_hertz' => audio_file_mono_sample_rate.to_s,
      'channels' => audio_file_mono_channels.to_s,
      'bit_rate_bps' => audio_file_mono_bit_rate_bps.to_s,
      'media_type' => audio_file_mono_media_type.to_s,
      'data_length_bytes' => audio_file_mono_data_length_bytes.to_s,
      'file_hash' => 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
      'original_format' => audio_file_mono_format.to_s
    }
  }

  context 'queues' do
    let(:expected_payload) {
      {
        'class' => BawWorkers::Jobs::AudioCheck::Action.to_s,
        'args' => [
          '2f65b9b2d3ffd4222b82102bc0e15e79',
          {
            'audio_params' => test_params
          }
        ]
      }
    }

    it 'checks we\'re using a manual queue' do
      expect(Resque.queue_from_class(BawWorkers::Jobs::AudioCheck::Action)).to end_with('_manual_tick')
    end

    it 'works on the media queue' do
      expect(Resque.queue_from_class(BawWorkers::Jobs::AudioCheck::Action)).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::AudioCheck::Action.action_enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      queued_query = { audio_params: test_params }

      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Jobs::AudioCheck::Action, queued_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Jobs::AudioCheck::Action, queued_query)).to eq(false)

      result1 = BawWorkers::Jobs::AudioCheck::Action.action_enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(Resque.enqueued?(BawWorkers::Jobs::AudioCheck::Action, queued_query)).to eq(true)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)

      result2 = BawWorkers::Jobs::AudioCheck::Action.action_enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(nil)
      expect(Resque.enqueued?(BawWorkers::Jobs::AudioCheck::Action, queued_query)).to eq(true)

      result3 = BawWorkers::Jobs::AudioCheck::Action.action_enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(nil)
      expect(Resque.enqueued?(BawWorkers::Jobs::AudioCheck::Action, queued_query)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end
  end

  context 'should execute perform method' do
    context 'raises error' do
      it 'with a params that is not a hash' do
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform('not a hash')
        }.to raise_error(ArgumentError, /Param was a 'String'\. It must be a 'Hash'\./)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'with a params missing required value' do
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(test_params.except('original_format'))
        }.to raise_error(ArgumentError, /Audio params must include original_format/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'with correct parameters when file does not exist' do
        original_params = test_params.dup

        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: Time.zone.parse('2010-02-23 20:42:00Z'),
            original_format: audio_file_mono_format
          }

        audio_original.possible_paths(media_request_params).each do |file|
          File.delete file if File.exist? file
        end

        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError,
                         /No existing files for.*?7bb0c719-143f-4373-a724-8138219006d9.*?\.ogg/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file hash is incorrect' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup
        original_params['file_hash'] = 'SHA256::this is really very wrong'

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError,
                         /File hashes DO NOT match for.*?:file_hash=>:fail/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file extension is incorrect' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup
        original_params['original_format'] = 'mp3'

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError, /No existing files for/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file hashes do not match' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        # arrange
        new_file = create_original_audio(media_request_params, audio_file_mono, true)

        # modify audio file
        a = ['010', '1111', '10', '10', '110', '1110', '001', '110', '000', '10', '011']
        File.open(new_file, 'ab') do |output|
          output.seek(0, IO::SEEK_END)
          output.write [a.join].pack('B*')
        end

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /File hashes DO NOT match for/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file integrity is uncertain' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        # arrange
        new_file = create_original_audio(media_request_params, audio_file_corrupt, true)

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::AudioToolError, /Header processing failed/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file hash is empty and other properties do not match' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        original_params['file_hash'] = 'SHA256::'
        original_params['duration_seconds'] = 12_345

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError,
                         /File hash and other properties DO NOT match.*?:file_hash=>:fail.*?:duration_seconds=>:fail/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when recorded date is in incorrect format' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        original_params['recorded_date'] = '2010-02-23 20:42:00+10:00'

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)
        }.to raise_error(ArgumentError, /recorded_date must be a UTC time \(i\.e\. end with Z\), given/)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end

    context 'is successful' do
      it 'with correct parameters for file with old style name' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_request_params, audio_file_mono, false, true)

        # act
        result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_possible_paths = audio_original.possible_paths(media_request_params)
        expect(File.basename(original_possible_paths.first)).to eq('7bb0c719-143f-4373-a724-8138219006d9_100224-0642.ogg')
        expect(File.basename(original_possible_paths.second)).to eq('7bb0c719-143f-4373-a724-8138219006d9_20100223-204200Z.ogg')

        expect(result[0][:moved_path]).to eq(File.expand_path(original_possible_paths.second))

        expect(File).not_to exist(original_possible_paths.first)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'with correct parameters for file with new style name' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true, true)

        # act
        result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_possible_paths = audio_original.possible_paths(media_request_params)
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File).not_to exist(original_possible_paths.first)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'with correct parameters when both old and new files exist' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true)
        create_original_audio(media_request_params, audio_file_mono, false)

        # act
        result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

        # assert
        expect(result.size).to eq(2)

        original_possible_paths = audio_original.possible_paths(media_request_params)
        expect(File.expand_path(original_possible_paths.first)).to eq(result[0][:file_path])
        expect(File.expand_path(original_possible_paths.second)).to eq(result[1][:file_path])

        expect(File).to exist(original_possible_paths.first)
        expect(File).to exist(original_possible_paths.second)

        expect(result[0][:moved_path]).to be_falsey
        expect(result[1][:moved_path]).to be_falsey

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when updating audio file properties' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup

        original_params['media_type'] = 'audio/mp3'
        original_params['sample_rate_hertz'] = 22_050
        original_params['channels'] = 5
        original_params['bit_rate_bps'] = 800
        original_params['data_length_bytes'] = 99
        original_params['duration_seconds'] = 120

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true, true)

        auth_token = 'auth token I am'
        email = 'address@example.com'
        password = 'password'
        xsrf_value = 'DFvcwhrXYL8AJKl%2BlZznx%2FJFz15%2BHKPQg%2BAXwYsOIHx%2BRxVEHDPya%2Fm%2Bv9BgbcVSsQ6CGi8%2BLLbzBCAtg%3D%3D'
        xsrf_decoded = 'DFvcwhrXYL8AJKl+lZznx/JFz15+HKPQg+AXwYsOIHx+RxVEHDPya/m+v9BgbcVSsQ6CGi8+LLbzBCAtg=='
        cookie_value = "XSRF-TOKEN=#{xsrf_value}; path=/"
        login_request = stub_request(:post, "#{default_uri}/security")
                        .with(body: get_api_security_request(email, password),
                              headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                                         'User-Agent' => 'Ruby' })
                        .to_return(status: 200, body: get_api_security_response(email,
                                                                                auth_token).to_json, headers: { 'Set-Cookie' => cookie_value })

        expected_request_body = {
          media_type: audio_file_mono_media_type.to_s,
          sample_rate_hertz: audio_file_mono_sample_rate.to_f,
          channels: audio_file_mono_channels,
          bit_rate_bps: audio_file_mono_bit_rate_bps,
          data_length_bytes: audio_file_mono_data_length_bytes,
          duration_seconds: audio_file_mono_duration_seconds.to_f
        }

        stub_request(:put, "#{default_uri}/audio_recordings/#{test_params['id']}")
          .with(body: expected_request_body.to_json,
                headers: { 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{auth_token}\"",
                           'Content-Type' => 'application/json', 'User-Agent' => 'Ruby',
                           'X-Xsrf-Token' => xsrf_decoded })
          .to_return(status: 200)

        # act
        result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_possible_paths = audio_original.possible_paths(media_request_params)
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File).not_to exist(original_possible_paths.first)

        expect(result[0][:api_response]).to eq(:success)

        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      it 'when file hash not given, and only file hash needs to be updated' do
        media_request_params =
          {
            uuid: '7bb0c719-143f-4373-a724-8138219006d9',
            datetime_with_offset: '2010-02-23 20:42:00Z',
            original_format: audio_file_mono_format
          }

        original_params = test_params.dup
        expected_request_body = {
          file_hash: original_params['file_hash']
        }
        original_params['file_hash'] = 'SHA256::'

        # arrange
        create_original_audio(media_request_params, audio_file_mono, true, true)

        auth_token = 'auth token I am'
        email = 'address@example.com'
        password = 'password'
        login_request = stub_request(:post, "#{default_uri}/security")
                        .with(body: get_api_security_request(email, password),
                              headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                                         'User-Agent' => 'Ruby' })
                        .to_return(status: 200, body: get_api_security_response(email, auth_token).to_json)

        stub_request(:put, "#{default_uri}/audio_recordings/#{test_params['id']}")
          .with(body: expected_request_body.to_json,
                headers: { 'Accept' => 'application/json', 'Authorization' => "Token token=\"#{auth_token}\"",
                           'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
          .to_return(status: 200)

        # act
        result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_possible_paths = audio_original.possible_paths(media_request_params)
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File).not_to exist(original_possible_paths.first)

        expect(result[0][:api_response]).to eq(:success)
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end

      context 'in dry run mode' do
        it 'does nothing even when there are changes to be made' do
          media_request_params =
            {
              uuid: '7bb0c719-143f-4373-a724-8138219006d9',
              datetime_with_offset: '2010-02-23 20:42:00Z',
              original_format: audio_file_mono_format
            }

          original_params = test_params.dup

          original_params['media_type'] = 'audio/mp3'
          original_params['sample_rate_hertz'] = 22_050
          original_params['channels'] = 5
          original_params['bit_rate_bps'] = 800
          original_params['data_length_bytes'] = 99
          original_params['duration_seconds'] = 120

          # arrange
          create_original_audio(media_request_params, audio_file_mono, false, true)

          auth_token = 'auth token I am'
          email = 'address@example.com'
          password = 'password'
          login_request = stub_request(:post, "#{default_uri}/security")
                          .with(body: get_api_security_request(email, password),
                                headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json',
                                           'User-Agent' => 'Ruby' })
                          .to_return(status: 200, body: get_api_security_response(email, auth_token).to_json)

          expected_request_body = {
            media_type: audio_file_mono_media_type.to_s,
            sample_rate_hertz: audio_file_mono_sample_rate.to_f,
            channels: audio_file_mono_channels,
            bit_rate_bps: audio_file_mono_bit_rate_bps,
            data_length_bytes: audio_file_mono_data_length_bytes,
            duration_seconds: audio_file_mono_duration_seconds.to_f
          }

          update_request = stub_request(:put, "#{default_uri}/audio_recordings/#{test_params['id']}")
                           .with(body: expected_request_body.to_json,
                                 headers: { 'Accept' => 'application/json',
                                            'Authorization' => "Token token=\"#{auth_token}\"", 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' })
                           .to_return(status: 200)

          # act
          #result = BawWorkers::Jobs::AudioCheck::Action.action_perform(original_params)

          result = audio_file_check.run(original_params, false)
          # assert
          expect(result.size).to eq(1)

          original_possible_paths = audio_original.possible_paths(media_request_params)
          expect(File.expand_path(original_possible_paths.first)).to eq(result[0][:file_path])
          expect(File.exist?(original_possible_paths.second)).to be_falsey,
                                                                 "File should not exist #{original_possible_paths.second}"

          expect(login_request).not_to have_been_requested
          login_request.should_not have_been_requested

          expect(update_request).not_to have_been_requested
          update_request.should_not have_been_requested

          expect(result[0][:api_response]).to eq(:dry_run)
          expect(ActionMailer::Base.deliveries.count).to eq(0)
        end
      end
    end
  end

  it 'runs standalone with errors' do
    csv_file = copy_test_audio_check_csv

    BawWorkers::ReadCsv.read_audio_recording_csv(csv_file) do |audio_params|
      audio_params[:datetime_with_offset] = audio_params[:recorded_date]
      create_original_audio(audio_params, audio_file_mono, false)
      # FileUtils.touch(File.join(audio_original.possible_dirs[0], '83/837df827-2be2-43ef-8f48-60fa0ee6ad37_930712-1552.asf'))
    end

    result = BawWorkers::Jobs::AudioCheck::Action.action_perform_rake(csv_file, false)

    expect(worker_log_content).to include('File hash and other properties DO NOT match')
    expect(result[:successes].size).to eq(0)
    expect(result[:failures].size).to eq(24)
  end

  it 'runs successfully using resque' do
    csv_file = copy_test_audio_check_csv

    result = BawWorkers::Jobs::AudioCheck::Action.action_enqueue_rake(csv_file, true)

    expect(worker_log_content).to match(/INFO-BawWorkers::Jobs::AudioCheck::Action-.+\] Job enqueue returned/)
    expect(result[:successes].size).to eq(24)
    expect(result[:failures].size).to eq(0)
  end
end
