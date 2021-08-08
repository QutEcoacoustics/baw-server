# frozen_string_literal: true

context 'with edge cases in media generation' do
  include ExampleImageHelpers
  include_context 'shared_test_helpers'

  # fill our audio storage with a fixture

  let(:uuid) { '7bb0c719-143f-4373-a724-8138219006d9' }
  let(:recorded_date) { Time.zone.parse('2019-09-13T00:00:01+1000') }
  let(:audio_payload) {
    BawWorkers::Models::AudioRequest.new(
      uuid: uuid,
      start_offset: 7100,
      end_offset: 7130,
      channel: 0,
      sample_rate: 22_050,
      datetime_with_offset: recorded_date,
      original_format: audio_file_bar_lt_metadata[:format],
      original_sample_rate: audio_file_bar_lt_metadata[:sample_rate],
      format: 'wav',
      media_type: 'audio/wav'
    )
  }
  let(:spectrogram_payload) {
    BawWorkers::Models::SpectrogramRequest.new(
      **audio_payload,
      format: 'png',
      media_type: 'image/png',
      window: 512,
      window_function: 'Hamming',
      colour: 'g'
    )
  }
  let!(:test_file) {
    link_original_audio(
      target: Fixtures.bar_lt_file,
      uuid: uuid,
      datetime_with_offset: recorded_date,
      original_format: audio_file_bar_lt_metadata[:format]
    )
  }

  before do
    clear_audio_cache
    clear_spectrogram_cache
  end

  after do
    test_file.unlink
  end

  # https://github.com/QutEcoacoustics/baw-server/issues/527
  context 'with race conditions in interleaved audio & spectrograms jobs targeting the same segment', :slow do
    # we're running all jobs in the RSpec environment not on the workers for this test
    pause_all_jobs

    def perform_many_times(path, job, payload)
      # 100 is a good size for general/CI testing - the test should take about 30 seconds
      # I've manually tested sizes 200 & 300 too, after about 500 the tools start to timeout on my dev box
      scale = 100
      scale.times.map {
        Concurrent::Promises.delay {
          # jitter helps ensure the promises don't execute in a manner that is predictable,
          # which better simulates incoming requests.
          sleep(rand * 0.1)
          FileUtils.rm_f(path)
          job.perform(payload)
        }
      }
    end

    def hash(path)
      BawWorkers::Config.file_info.generate_hash(path).hexdigest
    end

    def log_errors(error_classes)
      return if error_classes.empty?

      logger.info({
        failures: error_classes.transform_values(&:count)
      })
      error_classes.each do |error_class, grouping|
        logger.error('Example error', name: error_class.name, exception: grouping.first)
      end
    end

    # So this test is basically a stress test.
    # We queue up hundreds of jobs and expect there to be no exceptions, even though
    # the jobs are all running concurrently and treading on each other's toes.
    # We tried to write a more specific test, but the gymnastics required to setup a race condition
    # in the exact right way is extremely brittle and depends on mocking/stubbing/faking a lot of
    # internals, which are of course subject to change.
    it 'handles media generation race conditions gracefully' do
      audio_job = BawWorkers::Jobs::Media::AudioJob.perform_later!(audio_payload)
      spectrogram_job = BawWorkers::Jobs::Media::SpectrogramJob.perform_later!(spectrogram_payload)

      audio_cache_path = get_cached_audio_paths(audio_payload).first
      spectrogram_cache_path = get_cached_spectrogram_paths(spectrogram_payload).first

      # Run jobs once. They should (a) just work in a basic scenario and (b) generate a file we can use as a reference
      audio_job.perform(audio_payload)
      spectrogram_job.perform(spectrogram_payload)

      correct_audio = hash(audio_cache_path)
      correct_spectrogram = calculate_image_data_hash(spectrogram_cache_path)

      # Our test worker only has single concurrency, so instead we'll run both jobs locally, concurrently.
      all = (
        perform_many_times(audio_cache_path, audio_job, audio_payload) +
        perform_many_times(spectrogram_cache_path, spectrogram_job, spectrogram_payload)
      ).shuffle!

      # Extract the reason for promise rejection (failures) from results.
      _, _, reason = Concurrent::Promises.zip(*all).wait.result

      # Example exceptions that did occur but should no longer:
      #   BawAudioTools::Exceptions::FileEmptyError: Source exists, but has no content:
      #   Errno::ENOENT: No such file or directory @ apply2files
      #     When deleting the temporary file made by the job
      #   BawAudioTools::Exceptions::FileAlreadyExistsError: Target exists:
      #     When calling modify and the temp target exists
      #   BawAudioTools::Exceptions::AudioToolError: External Program: ... WAVE: RIFF header not found
      #   BawAudioTools::Exceptions::FileEmptyError: Source exists, but has no content
      error_classes = reason&.group_by(&:class) || {}

      log_errors(error_classes)

      expect(error_classes).to be_empty

      actual_audio = hash(audio_cache_path)
      actual_spectrogram = calculate_image_data_hash(spectrogram_cache_path)

      expect(actual_audio).to eq correct_audio
      expect(actual_spectrogram).to eq correct_spectrogram

      # as far as our work queue is concerned we've completed no jobs! Discard them
      clear_pending_jobs
    end
  end
end
