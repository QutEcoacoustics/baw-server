# frozen_string_literal: true

describe '.../media', :aggregate_failures, type: :request do
  include_context 'shared_test_helpers'

  create_audio_recordings_hierarchy

  let(:lt_recording) {
    create(
      :audio_recording,
      recorded_date: Time.zone.parse('2019-09-13T00:00:01+1000 '),
      duration_seconds: audio_file_bar_lt_metadata[:duration_seconds],
      media_type: audio_file_bar_lt_metadata[:format],
      original_file_name: Fixtures.bar_lt_file.basename,
      status: :ready,
      site: site
    )
  }
  # backfill our audio storage with a fixture
  let!(:test_file) {
    link_original_audio(
      target: Fixtures.bar_lt_file,
      uuid: lt_recording.uuid,
      datetime_with_offset: lt_recording.recorded_date,
      original_format: audio_file_bar_lt_metadata[:format]
    )
  }

  before do
    clear_audio_cache
  end

  after do
    test_file.unlink
  end

  def media_url(start_offset, end_offset, format = 'mp3')
    "/audio_recordings/#{lt_recording.id}/media.#{format}?start_offset=#{start_offset}&end_offset=#{end_offset}"
  end

  # we're trying to emulate an error case from production,
  # https://github.com/QutEcoacoustics/baw-server/issues/521
  # - where a directory did not exist and it caused an exception
  # - it happened for a range request
  # - it happened with the redis cache
  context 'with redis fast caching' do
    # don't let the worker actually run
    pause_all_jobs

    it 'generated media do not generate Errno::ENOENT when directories do not exist' do
      # we do not want the job to run, we do want the redis cache to return a result

      # get the expected key for this job
      key = "#{lt_recording.uuid}_0.0_30.0_0_22050.mp3"

      # stuff a fake response in so we can serve it immediately
      BawWorkers::Config.redis_communicator.set_file(key, Fixtures.audio_file_mono)
      expect(BawWorkers::Config.redis_communicator.exists_file?(key)).to be true

      # this was throwing with:
      # An Errno::ENOENT occurred in media#show:
      #
      #   No such file or directory @ rb_sysopen - /data/test/cached_audio/7a/7a51b949-f593-487b-a47a-7ad9874f9af9_0.0_30.0_0_22050.mp3
      #   app/models/range_request.rb:122:in `initialize'
      #
      # The range request headers are what triggered the bug
      get media_url(0, 30), headers: with_range_request_headers(media_request_headers(reader_token), ranges: [0..])

      expect_success
      expect(audio_cache.possible_dirs.map { |d| Pathname(d) }).to all(be_empty)

      expect(response.content_type).to eq('audio/mpeg')
      # our range request implementation limits unbounded requests to 512 kB
      expect(response.content_length).to be_within(0).of(RangeRequest.new.max_range_size)
      expect(response.headers['X-Error-Message']).to be_nil

      clear_pending_jobs
    end
  end
end
