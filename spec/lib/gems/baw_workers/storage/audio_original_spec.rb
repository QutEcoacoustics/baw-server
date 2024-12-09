# frozen_string_literal: true

describe BawWorkers::Storage::AudioOriginal do
  include_context 'shared_test_helpers'

  let(:audio_original) { BawWorkers::Config.original_audio_helper }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:datetime) { Time.zone.parse('2012-03-02 16:05:37+1100') }
  let(:partial_path) { uuid[0, 2] }
  let(:format_audio) { 'wav' }

  let(:original_format) { 'mp3' }
  let(:original_file_name_v1) { "#{uuid}_120302-1505.#{original_format}" } # depends on let(:datetime)
  let(:original_file_name_v2) { "#{uuid}_20120302-050537Z.#{original_format}" } # depends on let(:datetime)
  let(:original_file_name_v3) { "#{uuid}.#{original_format}" }

  let(:opts) {
    {
      uuid:,
      datetime_with_offset: datetime,
      original_format:
    }
  }

  before do
    clear_original_audio
  end

  it 'no storage directories exist' do
    expect_empty_directories(audio_original.existing_dirs)
  end

  it 'possible dirs match settings' do
    expect(audio_original.possible_dirs).to match_array Settings.paths.original_audios
  end

  it 'existing dirs match settings' do
    FileUtils.mkdir_p(Settings.paths.original_audios[0])
    expect(audio_original.existing_dirs).to match_array Settings.paths.original_audios
    FileUtils.rm_rf(Settings.paths.original_audios[0])
  end

  it 'possible paths match settings for v1 names' do
    files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v1)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v1)).to match_array files
  end

  it 'possible paths match settings for v2 names' do
    files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v2)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v2)).to match_array files
  end

  it 'possible paths match settings for v3 names' do
    files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v3)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v3)).to match_array files
  end

  it 'existing paths match settings for v1 names' do
    files = [
      File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v1)
    ]
    dir = Settings.paths.original_audios[0]
    sub_dir = File.join(dir, partial_path)
    FileUtils.mkpath(sub_dir)
    FileUtils.touch(files[0])
    expect(audio_original.possible_paths_file(opts, original_file_name_v1)).to match_array files
    FileUtils.rm_rf(dir)
  end

  it 'existing paths match settings for v2 names' do
    files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v2)]
    dir = Settings.paths.original_audios[0]
    sub_dir = File.join(dir, partial_path)
    FileUtils.mkpath(sub_dir)
    FileUtils.touch(files[0])
    expect(audio_original.possible_paths_file(opts, original_file_name_v2)).to match_array files
    FileUtils.rm_rf(dir)
  end

  it 'existing paths match settings for v3 names' do
    files = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v3)]
    dir = Settings.paths.original_audios[0]
    sub_dir = File.join(dir, partial_path)
    FileUtils.mkpath(sub_dir)
    FileUtils.touch(files[0])
    expect(audio_original.possible_paths_file(opts, original_file_name_v3)).to match_array files
    FileUtils.rm_rf(dir)
  end

  it 'creates the correct old name' do
    expect(audio_original.file_name_10(opts)).to eq original_file_name_v1
  end

  it 'creates the correct new name' do
    expect(audio_original.file_name_utc(opts)).to eq original_file_name_v2
  end

  it 'creates the correct v3 name' do
    expect(audio_original.file_name_uuid(opts)).to eq original_file_name_v3
  end

  it 'creates the correct partial path for v1 names' do
    expect(audio_original.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct partial path for v2 names' do
    expect(audio_original.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct partial path for v3 names' do
    expect(audio_original.partial_path(opts)).to eq partial_path
  end

  it 'creates the correct full path for v1 names' do
    expected = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v1)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v1)).to eq expected
  end

  it 'creates the correct full path for v2 names for a single file' do
    expected = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v2)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v2)).to eq expected
  end

  it 'creates the correct full path for v3 names for a single file' do
    expected = [File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v3)]
    expect(audio_original.possible_paths_file(opts, original_file_name_v3)).to eq expected
  end

  it 'creates the correct full path' do
    expected = [
      File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v3),
      File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v1),
      File.join(Settings.paths.original_audios[0], partial_path, original_file_name_v2)
    ]
    expect(audio_original.possible_paths(opts)).to eq expected
  end

  it 'detects that Date object is not valid' do
    expect {
      new_opts = opts.dup
      new_opts[:datetime_with_offset] = datetime.to_s
      audio_original.file_name_10(new_opts)
    }.to raise_error(ArgumentError, /datetime_with_offset must be an ActiveSupport::TimeWithZone/)
  end
end
