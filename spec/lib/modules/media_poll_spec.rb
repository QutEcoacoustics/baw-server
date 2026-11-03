# frozen_string_literal: true

describe MediaPoll do
  describe '.poll_resque_and_media with Redis caching' do
    let(:path) { '/tmp/media-poll-test.wav' }
    let(:job_id) { 'media-poll-test-job' }
    let(:cache) { BawWorkers::Config.redis_communicator }
    let(:working_status) {
      instance_double(BawWorkers::ActiveJob::Status::StatusData,
        completed?: false, status: 'working', job_id:, time: Time.zone.now)
    }
    let(:completed_status) { instance_double(BawWorkers::ActiveJob::Status::StatusData, completed?: true) }
    let(:status_store) { BawWorkers::ActiveJob::Status::Persistence }

    before do
      allow(Settings.actions.media).to receive(:cache_to_redis).and_return(true)
    end

    def poll_media(wait_max: 1)
      MediaPoll.poll_resque_and_media([path], :audio, {}, wait_max, job_id:, poll_delay: 0.001)
    end

    it 'waits for Redis when a disk file is visible but the worker is still running' do
      content = "\x00\xffgenerated media".b
      attempts = 0
      allow(status_store).to receive(:get).with(job_id).and_return(working_status)
      allow(cache).to receive(:get_file).with('media-poll-test.wav', an_instance_of(StringIO)) do |_, buffer|
        attempts += 1
        if attempts == 1
          nil
        else
          buffer.write(content)
          buffer.close
          content.bytesize
        end
      end
      allow(MediaPoll).to receive(:get_existing_files).and_return([path])

      expect(poll_media).to eq(in_memory_file: content, existing_files: [], resque_status: working_status)
      expect(status_store).to have_received(:get).with(job_id).twice
      expect(cache).to have_received(:get_file).twice
      expect(MediaPoll).not_to have_received(:get_existing_files)
    end

    it 'treats an empty Redis value as a cache hit' do
      allow(status_store).to receive(:get).with(job_id).and_return(working_status)
      allow(cache).to receive(:get_file).with('media-poll-test.wav', an_instance_of(StringIO)) do |_, buffer|
        buffer.close
        0
      end

      expect(poll_media).to eq(in_memory_file: '', existing_files: [], resque_status: working_status)
      expect(status_store).to have_received(:get).with(job_id).once
      expect(cache).to have_received(:get_file).once
    end

    it 'returns no in-memory file when the worker completes without a Redis value' do
      allow(status_store).to receive(:get).with(job_id).and_return(completed_status)
      allow(cache).to receive(:get_file).and_return(nil)
      allow(MediaPoll).to receive(:get_existing_files)

      expect(poll_media).to eq(in_memory_file: nil, existing_files: [], resque_status: completed_status)
      expect(status_store).to have_received(:get).with(job_id).once
      expect(cache).to have_received(:get_file).once
      expect(MediaPoll).not_to have_received(:get_existing_files)
    end
  end
end
