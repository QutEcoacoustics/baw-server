require 'spec_helper'

describe BawWorkers::Action::AudioFileCheckAction do
  include_context 'media_file'

  let(:queue_name) { BawWorkers::Settings.resque.queues.maintenance }

  let(:test_params) {
    {
        id: 5,
        uuid: '7bb0c719-143f-4373-a724-8138219006d9',
        recorded_date: Time.zone.now,
        duration_seconds: audio_file_mono_duration_seconds,
        sample_rate_hertz: audio_file_mono_sample_rate,
        channels: audio_file_mono_channels,
        bit_rate_bps: audio_file_mono_bit_rate_bps,
        media_type: audio_file_mono_media_type.to_s,
        data_length_bytes: audio_file_mono_data_length_bytes,
        file_hash: 'SHA256::c110884206d25a83dd6d4c741861c429c10f99df9102863dde772f149387d891',
        original_format: audio_file_mono_format
    }
  }

  context 'queues' do

    let(:expected_payload) {
      {
          class: 'BawWorkers::Action::AudioFileCheckAction',
          args: [test_params]
      }
    }

    it 'works on the media queue' do
      expect(Resque.queue_from_class(BawWorkers::Action::AudioFileCheckAction)).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Action::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      # {:a => 1, :b => 2}.stringify_keys.should =~ {"a" => 1, "b" => 2}
      expect(deep_stringify_keys(expected_payload)).to eq(actual)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      result1 = BawWorkers::Action::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Action::AudioFileCheckAction, test_params)).to eq(true)

      result2 = BawWorkers::Action::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Action::AudioFileCheckAction, test_params)).to eq(true)

      result3 = BawWorkers::Action::AudioFileCheckAction.enqueue(test_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Action::AudioFileCheckAction, test_params)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(deep_stringify_keys(expected_payload)).to eq(actual)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(deep_stringify_keys(expected_payload)).to eq(popped)
      expect(Resque.size(queue_name)).to eq(0)
    end

  end

  context 'should execute perform method' do

    context 'raises error' do
      it 'with a params that is not a hash' do
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform('not a hash')
        }.to raise_error(ArgumentError, /Media request params was a 'String'\. It must be a 'Hash'\./)
      end

      it 'with a params missing required value' do
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(test_params.except(:original_format))
        }.to raise_error(ArgumentError, /Audio params must include original_format/)
      end

      it 'with correct parameters when file does not exist' do

        original_params = test_params.dup

        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError, /No existing files for.*?7bb0c719-143f-4373-a724-8138219006d9.*?\.ogg/)

      end

      it 'when file hash is incorrect' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup
        original_params[:file_hash] = 'SHA256::this is really very wrong'

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /File hashes DO NOT match for.*?:file_hash=>:fail/)
      end

      it 'when file extension is incorrect' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup
        original_params[:original_format] = 'mp3'

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        # act
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileNotFoundError, /No existing files for/)
      end

      it 'when file hashes do not match' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        # arrange
        new_file = create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        # modify audio file
        a = ["010", "1111", "10", "10", "110", "1110", "001", "110", "000", "10", "011"]
        File.open(new_file, 'ab' ) do |output|
          output.seek(0, IO::SEEK_END)
          output.write [a.join].pack('B*')
        end

        # act
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /File hashes DO NOT match for/)
      end

      it 'when file integrity is uncertain' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        # arrange
        new_file = create_original_audio(media_cache_tool, media_request_params, audio_file_corrupt, true)

        # act
        expect {
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /Ffmpeg output contained warning/)
      end

      it 'when file hash is empty and other properties do not match' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup
        expected_request_body = {
            file_hash: original_params[:file_hash]
        }
        original_params[:file_hash] = 'SHA256::'
        original_params[:duration_seconds] = 12345

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        # act
        expect{
          BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        }.to raise_error(BawAudioTools::Exceptions::FileCorruptError, /File hash and other properties DO NOT match.*?:file_hash=>:fail.*?:duration_seconds=>:fail/)

      end

    end

    context 'is successful' do
      it 'with correct parameters for file with old style name' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono)

        # act
        result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:moved_path])

        expect(File.exist?(original_possible_paths.first)).to be_falsey
      end

      it 'with correct parameters for file with new style name' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        # act
        result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File.exist?(original_possible_paths.first)).to be_falsey

      end

      it 'with correct parameters when both old and new files exist' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, false)

        # act
        result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)

        # assert
        expect(result.size).to eq(2)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.first)).to eq(result[0][:file_path])
        expect(File.expand_path(original_possible_paths.second)).to eq(result[1][:file_path])

        expect(File.exist?(original_possible_paths.first)).to be_truthy
        expect(File.exist?(original_possible_paths.second)).to be_truthy

        expect(result[0][:moved_path]).to be_falsey
        expect(result[1][:moved_path]).to be_falsey

      end


      it 'when updating audio file properties' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        original_params[:media_type] = 'audio/mp3'
        original_params[:sample_rate_hertz] = 22050
        original_params[:channels] = 5
        original_params[:bit_rate_bps] = 800
        original_params[:data_length_bytes] = 99
        original_params[:duration_seconds] = 120

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        auth_token = 'auth token I am'
        email = 'address@example.com'
        password = 'password'
        login_request = stub_request(:post, "http://localhost:3030/security/sign_in").
            with(:body => "{\"email\":\""+email+"\",\"password\":\""+password+"\"}",
                 :headers => {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(status: 200, body: '{"success":true,"auth_token":"'+auth_token+'","email":"'+email+'"}')


        expected_request_body = {
            media_type: audio_file_mono_media_type.to_s,
            sample_rate_hertz: audio_file_mono_sample_rate.to_f,
            channels: audio_file_mono_channels,
            bit_rate_bps: audio_file_mono_bit_rate_bps,
            data_length_bytes: audio_file_mono_data_length_bytes,
            duration_seconds: audio_file_mono_duration_seconds.to_f
        }

        stub_request(:put, "http://localhost:3030/audio_recordings/id").
            with(:body => expected_request_body.to_json,
                 :headers => {'Accept' => 'application/json', 'Authorization' => 'Token token="'+auth_token+'"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(:status => 200)

        # act
        result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File.exist?(original_possible_paths.first)).to be_falsey

        expect(result[0][:api_response]).to eq(:success)

      end

      it 'when file hash not given, and only file hash needs to be updated' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup
        expected_request_body = {
            file_hash: original_params[:file_hash]
        }
        original_params[:file_hash] = 'SHA256::'

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono, true)

        auth_token = 'auth token I am'
        email = 'address@example.com'
        password = 'password'
        login_request = stub_request(:post, "http://localhost:3030/security/sign_in").
            with(:body => "{\"email\":\""+email+"\",\"password\":\""+password+"\"}",
                 :headers => {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(status: 200, body: '{"success":true,"auth_token":"'+auth_token+'","email":"'+email+'"}')

        stub_request(:put, "http://localhost:3030/audio_recordings/id").
            with(:body => expected_request_body.to_json,
                 :headers => {'Accept' => 'application/json', 'Authorization' => 'Token token="'+auth_token+'"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(:status => 200)

        # act
        result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)

        # assert
        expect(result.size).to eq(1)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.second)).to eq(result[0][:file_path])

        expect(File.exist?(original_possible_paths.first)).to be_falsey

        expect(result[0][:api_response]).to eq(:success)

      end

      context 'in dry run mode' do

      it 'does nothing even when there are changes to be made' do
        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
            }

        original_params = test_params.dup

        original_params[:media_type] = 'audio/mp3'
        original_params[:sample_rate_hertz] = 22050
        original_params[:channels] = 5
        original_params[:bit_rate_bps] = 800
        original_params[:data_length_bytes] = 99
        original_params[:duration_seconds] = 120

        # arrange
        create_original_audio(media_cache_tool, media_request_params, audio_file_mono)

        auth_token = 'auth token I am'
        email = 'address@example.com'
        password = 'password'
        login_request = stub_request(:post, "http://localhost:3030/security/sign_in").
            with(:body => "{\"email\":\""+email+"\",\"password\":\""+password+"\"}",
                 :headers => {'Accept' => 'application/json', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(status: 200, body: '{"success":true,"auth_token":"'+auth_token+'","email":"'+email+'"}')


        expected_request_body = {
            media_type: audio_file_mono_media_type.to_s,
            sample_rate_hertz: audio_file_mono_sample_rate.to_f,
            channels: audio_file_mono_channels,
            bit_rate_bps: audio_file_mono_bit_rate_bps,
            data_length_bytes: audio_file_mono_data_length_bytes,
            duration_seconds: audio_file_mono_duration_seconds.to_f
        }

        update_request = stub_request(:put, "http://localhost:3030/audio_recordings/id").
            with(:body => expected_request_body.to_json,
                 :headers => {'Accept' => 'application/json', 'Authorization' => 'Token token="'+auth_token+'"', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby'}).
            to_return(:status => 200)

        # act
        #result = BawWorkers::Action::AudioFileCheckAction.perform(original_params)
        audio_file_check = BawWorkers::AudioFileCheck.new(BawWorkers::Settings.logger, true)
        result = audio_file_check.run(original_params)
        # assert
        expect(result.size).to eq(1)

        original_file_names = media_cache_tool.original_audio_file_names(media_request_params)
        original_possible_paths = original_file_names.map { |source_file| media_cache_tool.cache.possible_storage_paths(media_cache_tool.cache.original_audio, source_file) }.flatten
        expect(File.expand_path(original_possible_paths.first)).to eq(result[0][:file_path])
        expect(File.exist?(original_possible_paths.second)).to be_falsey, "File should not exist #{original_possible_paths.second}"

        expect(login_request).to_not have_been_requested
        login_request.should_not have_been_requested

        expect(update_request).to_not have_been_requested
        update_request.should_not have_been_requested

        expect(result[0][:api_response]).to eq(:noaction)
      end
      end

    end
  end
end