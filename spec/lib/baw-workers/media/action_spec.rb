require 'spec_helper'

describe BawWorkers::Media::Action do
  include_context 'media_file'

  let(:queue_name) { BawWorkers::Settings.actions.media.queue }

  context 'queues' do

    let(:test_media_request_params) { {testing: :testing} }
    let(:expected_payload) {
      {
          'class' => 'BawWorkers::Media::Action',
          'args' => [
              '10fc094504a0a38f859f35d1b3055ca1',
              {
                  'media_type' => 'audio',
                  'media_request_params' =>
                      {
                          'testing' => 'testing'
                      }
              }
          ]
      }
    }

    it 'works on the media queue' do
      expect(Resque.queue_from_class(BawWorkers::Media::Action)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::Media::Action.action_enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'does not enqueue the same payload into the same queue more than once' do

      queued_query = {media_type: :audio, media_request_params: test_media_request_params}

      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(false)

      result1 = BawWorkers::Media::Action.action_enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to eq(true)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(true)

      result2 = BawWorkers::Media::Action.action_enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(true)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(true)

      result3 = BawWorkers::Media::Action.action_enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(true)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end

    it 'can retrieve the job' do
      queued_query = {media_type: :audio, media_request_params: test_media_request_params}
      queued_query_normalised = BawWorkers::ResqueJobId.normalise({media_type: :audio, media_request_params: test_media_request_params})

      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(false)

      result1 = BawWorkers::Media::Action.action_enqueue(:audio, test_media_request_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to eq(true)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Media::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Media::Action, queued_query)).to eq(true)

      found = BawWorkers::ResqueApi.jobs_of_with(BawWorkers::Media::Action, queued_query)
      job_id = BawWorkers::ResqueJobId.create_id_props(BawWorkers::Media::Action, queued_query)
      status = Resque::Plugins::Status::Hash.get(job_id)

      expect(found.size).to eq(1)
      expect(found[0]['class']).to eq(BawWorkers::Media::Action.to_s)
      expect(found[0]['queue']).to eq(queue_name)
      expect(found[0]['args'].size).to eq(2)
      expect(found[0]['args'][0]).to eq(job_id)
      expect(found[0]['args'][1]).to eq(queued_query_normalised)

      expect(job_id).to_not be_nil

      expect(status.status ).to eq('queued')
      expect(status.uuid ).to eq(job_id)
      expect(status.options ).to eq(queued_query_normalised)

    end

  end

  context 'executes perform method' do
    context 'raises error' do

    it 'when params is not a hash' do
      expect {
        BawWorkers::Media::Action.action_perform(:audio, 'not a hash')
      }.to raise_error(ArgumentError, /Media request params was a 'String'\. It must be a 'Hash'\./)
    end

    it 'when media type is invalid' do
      expect {
        BawWorkers::Media::Action.action_perform(:not_valid_param, {})
      }.to raise_error(ArgumentError, /Media type 'not_valid_param' is not in list of valid media types/)
    end

    it 'when recorded date is invalid' do

      media_request_params =
          {
              uuid: '7bb0c719-143f-4373-a724-8138219006d9',
              format: 'png',
              media_type: 'image/png',
              start_offset: 5,
              end_offset: 10,
              channel: 0,
              sample_rate: 22050,
              datetime_with_offset: 'blah blah blah',
              original_format: audio_file_mono_format,
              window: 512,
              window_function: 'Hamming',
              colour: 'g'
          }

      expect {
        BawWorkers::Media::Action.action_perform(:audio, media_request_params)
      }.to raise_error(ArgumentError, /Provided value for datetime_with_offset is not valid/)
    end

    end

    context 'generate spectrogram' do

      it 'raises error with no params' do
        expect {
          BawWorkers::Media::Action.action_perform(:spectrogram, {})
        }.to raise_error(ArgumentError, /Must provide a value for datetime_with_offset/)
      end

      it 'raises error with some bad params' do
        expect {
          BawWorkers::Media::Action.action_perform(:spectrogram, {datetime_with_offset: Time.zone.now})
        }.to raise_error(ArgumentError, /Required parameter missing: uuid/)
      end

      it 'is successful with correct parameters' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                format: 'png',
                media_type: 'image/png',
                start_offset: 5,
                end_offset: 10,
                channel: 0,
                sample_rate: 22050,
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format,
                window: 512,
                window_function: 'Hamming',
                colour: 'g'
            }
        # arrange
        create_original_audio(media_request_params, audio_file_mono)

        # act
        target_existing_paths = BawWorkers::Media::Action.action_perform(:spectrogram, media_request_params)

        # assert
        expected_paths = get_cached_spectrogram_paths(media_request_params)
        expect(target_existing_paths.size).to eq(1)
        expect(target_existing_paths[0]).to eq(expected_paths[0])

      end

    end

    context 'cut audio' do

      it 'raises error with no params' do
        expect {
          BawWorkers::Media::Action.action_perform(:audio, {})
        }.to raise_error(ArgumentError, /Must provide a value for datetime_with_offset/)
      end

      it 'raises error with some bad params' do
        expect {
          BawWorkers::Media::Action.action_perform(:audio, {datetime_with_offset: Time.zone.now})
        }.to raise_error(ArgumentError, /Required parameter missing: uuid/)
      end

      it 'is successful with correct parameters' do

        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                format: 'wav',
                media_type: 'audio/wav',
                start_offset: 5,
                end_offset: 10,
                channel: 0,
                sample_rate: 22050,
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format
            }
        # arrange
        create_original_audio(media_request_params, audio_file_mono)

        # act
        target_existing_paths = BawWorkers::Media::Action.action_perform(:audio, media_request_params)

        # assert
        expected_paths = get_cached_audio_paths(media_request_params)
        expect(target_existing_paths.size).to eq(1)
        expect(target_existing_paths[0]).to eq(expected_paths[0])

      end

      it 'runs a worker that processes the media_test queue' do
        # arrange

        # create original audio file
        media_request_params =
            {
                uuid: '7bb0c719-143f-4373-a724-8138219006d9',
                format: 'wav',
                media_type: 'audio/wav',
                start_offset: 5,
                end_offset: 10,
                channel: 0,
                sample_rate: 22050,
                datetime_with_offset: Time.zone.now,
                original_format: audio_file_mono_format
            }

        create_original_audio(media_request_params, audio_file_mono)

        BawWorkers::Media::Action.action_enqueue(:audio, media_request_params)

        # act
        emulate_resque_worker(BawWorkers::Media::Action.queue)

        # assert
        expected_paths = get_cached_audio_paths(media_request_params)
        expect(expected_paths.size).to eq(1)
        expect(File.exists?(expected_paths[0])).to be_truthy
      end

    end

  end
end