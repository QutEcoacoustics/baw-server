# frozen_string_literal: true

describe BawWorkers::Jobs::Media::AudioJob do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  pause_all_jobs

  let(:queue_name) { Settings.actions.media.queue }

  let(:test_payload) {
    BawWorkers::Models::AudioRequest.new(
      uuid: '7bb0c719-143f-4373-a724-8138219006d9',
      format: 'wav',
      media_type: 'audio/wav',
      start_offset: 5,
      end_offset: 10,
      channel: 0,
      sample_rate: 22_050,
      datetime_with_offset: Time.zone.now,
      original_format: audio_file_mono_format,
      original_sample_rate: 44_100
    )
  }

  describe 'queues' do
    it 'works on the media queue' do
      expect(BawWorkers::Jobs::Media::AudioJob.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::Media::AudioJob.perform_later!(test_payload)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Media::AudioJob)
      clear_pending_jobs
    end

    it 'has a sensible name' do
      job = BawWorkers::Jobs::Media::AudioJob.perform_later!(test_payload)

      expected = 'Audio request: [5.0-10.0), format=wav'
      expect(job.name).to eq(expected)
      expect(job.status.name).to eq(expected)

      clear_pending_jobs
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect_enqueued_jobs(0)

      job = BawWorkers::Jobs::Media::AudioJob.perform_later!(test_payload)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Media::AudioJob)
      expect(job.job_id).not_to be_nil

      job2 = BawWorkers::Jobs::Media::AudioJob.new(test_payload)
      expect(job2.enqueue).to eq false

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Media::AudioJob)
      expect(job2.job_id).to eq job.job_id
      expect(job2.unique?).to eq false

      clear_pending_jobs
    end

    it 'can query job status for a duplicate job' do
      expect_enqueued_jobs(0)

      job1 = BawWorkers::Jobs::Media::AudioJob.perform_later!(test_payload)

      result = BawWorkers::Jobs::Media::AudioJob.try_perform_later(test_payload)
      expect(result).to be_an_instance_of(::Dry::Monads::Failure)
      job2 = result.failure
      expect(job2.job_id).to eq job1.job_id
      expect(job2.unique?).to eq false
      expect(job2.status).to eq job1.status # structurally equal 😮

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Media::AudioJob)

      perform_jobs(count: 1)

      job1.refresh_status!
      job2.refresh_status!

      expect(job1.status.status).to eq job2.status.status
    end
  end

  context 'with bad arguments, raises error' do
    it 'when params is not a payload' do
      expect {
        BawWorkers::Jobs::Media::AudioJob.perform_now({ media_type: :audio })
      }.to raise_error(
        TypeError,
        'Argument (`Hash`) for parameter `payload` does not have expected type `BawWorkers::Models::AudioRequest`'
      )

      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'when params is payload with the wrong request type' do
      payload =     BawWorkers::Models::SpectrogramRequest.new(
        uuid: '7bb0c719-143f-4373-a724-8138219006d9',
        start_offset: 5,
        end_offset: 10,
        channel: 0,
        sample_rate: 22_050,
        datetime_with_offset: Time.zone.now,
        original_format: audio_file_mono_format,
        original_sample_rate: 44_100,
        format: 'png',
        media_type: 'image/png',
        window: 512,
        window_function: 'Hamming',
        colour: 'g'
      )
      expect {
        BawWorkers::Jobs::Media::AudioJob.perform_now(payload)
      }.to raise_error(
        TypeError,
        'Argument (`BawWorkers::Models::SpectrogramRequest`) for parameter `payload` does not have expected type `BawWorkers::Models::AudioRequest`'
      )

      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end

    it 'when recorded date is invalid' do
      expect {
        test_payload.new(datetime_with_offset: 'blah blah blah')
      }.to raise_error(Dry::Struct::Error, /has invalid type for :datetime_with_offset/)
    end
  end

  context 'when generating an audio segment' do
    it 'is successful with correct parameters' do
      # arrange
      create_original_audio(test_payload, audio_file_mono)

      # act
      job = BawWorkers::Jobs::Media::AudioJob.perform_later!(
        test_payload
      )
      perform_jobs(count: 1)

      # assert
      job.refresh_status!
      expect(job.status).to be_completed

      expect_jobs_to_be(completed: 1)

      expected_paths = get_cached_audio_paths(test_payload)
      expect(File).to exist(*expected_paths)

      expect(ActionMailer::Base.deliveries.count).to eq(0)

      # expect file to be in redis
      expected_paths.each do |path|
        path = Pathname(path)
        expect(BawWorkers::Config.redis_communicator.exists_file?(path.basename)).to eq true
      end
    end
  end
end
