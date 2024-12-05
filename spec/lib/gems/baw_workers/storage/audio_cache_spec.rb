# frozen_string_literal: true

describe BawWorkers::Storage::AudioCache do
  include_context 'shared_test_helpers'
  let(:audio_cache) { BawWorkers::Config.audio_cache_helper }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:datetime) { Time.zone.parse('2012-03-02 16:05:37+1100') }
  let(:end_offset) { 20.02 }
  let(:partial_path) { uuid[0, 2] }

  let(:start_offset) { 8.1 }
  let(:channel) { 0 }
  let(:sample_rate) { 22_050 }
  let(:format_audio) { 'wav' }

  let(:opts) {
    {
      uuid:,
      start_offset:,
      end_offset:,
      channel:,
      sample_rate:,
      format: format_audio
    }
  }

  let(:cached_audio_file_name_defaults) { "#{uuid}_0.0_#{end_offset}_0_22050.mp3" }
  let(:cached_audio_file_name_given_parameters) {
    "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{sample_rate}.#{format_audio}"
  }

  before do
    clear_audio_cache
  end

  it 'no storage directories exist' do
    expect_empty_directories(audio_cache.existing_dirs)
  end

  it 'paths match settings' do
    expect(audio_cache.possible_dirs).to match_array Settings.paths.cached_audios
  end

  it 'creates the correct name' do
    expect(
      audio_cache.file_name(opts)
    ).to eq cached_audio_file_name_given_parameters
  end

  context 'checking validation of sample rate' do
    let(:non_standard_sample_rate) { 12_345 }
    # file name with non-standard sample rate
    let(:cached_audio_file_name_given_parameters_nssr) {
      "#{uuid}_#{start_offset}_#{end_offset}_#{channel}_#{non_standard_sample_rate}.#{format_audio}"
    }

    it 'creates the correct name with non standard original sample rate' do
      expect(
        audio_cache.file_name(
          uuid:,
          start_offset:,
          end_offset:,
          channel:,
          sample_rate: non_standard_sample_rate,
          original_sample_rate: non_standard_sample_rate,
          format: format_audio
        )
      ).to eq cached_audio_file_name_given_parameters_nssr
    end

    it 'creates the correct name with non standard original sample rate and a standard requested sample rate' do
      expect(
        audio_cache.file_name(
          uuid:,
          start_offset:,
          end_offset:,
          channel:,
          sample_rate:,
          original_sample_rate: non_standard_sample_rate,
          format: format_audio
        )
      ).to eq cached_audio_file_name_given_parameters
    end

    it 'fails validation with invalid sample rate' do
      expect {
        audio_cache.file_name(
          uuid:,
          start_offset:,
          end_offset:,
          channel:,
          sample_rate: 75_757,
          original_sample_rate: non_standard_sample_rate,
          format: format_audio
        )
      }.to raise_error(ArgumentError)
    end

    it 'fails validation with non standard sample rate and original sample rate not supplied' do
      expect {
        audio_cache.file_name(
          uuid:,
          start_offset:,
          end_offset:,
          channel:,
          sample_rate: non_standard_sample_rate,
          format: format_audio
        )
      }.to raise_error(ArgumentError)
    end

    it 'fails validation with a sample rate not supported by the format (mp3)' do
      expect {
        audio_cache.file_name(
          uuid:,
          start_offset:,
          end_offset:,
          channel:,
          sample_rate: non_standard_sample_rate,
          original_sample_rate: non_standard_sample_rate,
          format: 'mp3'
        )
      }.to raise_error(ArgumentError)
    end
  end

  it 'creates the correct partial path' do
    expect(audio_cache.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct full path for a single file' do
    expected = [File.join(Settings.paths.cached_audios[0], partial_path, cached_audio_file_name_defaults)]
    expect(audio_cache.possible_paths_file(opts, cached_audio_file_name_defaults)).to eq expected
  end

  it 'creates the correct full path' do
    expected = [File.join(Settings.paths.cached_audios[0], partial_path, cached_audio_file_name_given_parameters)]
    expect(audio_cache.possible_paths(opts)).to eq expected
  end
end
