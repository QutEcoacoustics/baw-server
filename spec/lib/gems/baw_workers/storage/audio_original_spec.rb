# frozen_string_literal: true

require 'support/shared_test_helpers'

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
    Dir.mkdir(Settings.paths.original_audios[0]) unless Dir.exist?(Settings.paths.original_audios[0])
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

  it 'parses a valid v2 file name correctly' do
    path = audio_original.possible_paths_file(opts, original_file_name_v2)

    path_info = audio_original.parse_file_path(path[0])

    expect(path.size).to eq 1
    expect(path.first).to eq("#{BawWorkers::Config.original_audio_helper.possible_dirs[0]}/54/5498633d-89a7-4b65-8f4a-96aa0c09c619_20120302-050537Z.mp3")

    expect(path_info[:uuid]).to eq uuid
    expect(path_info[:datetime_with_offset]).to eq datetime
    expect(path_info[:original_format]).to eq original_format
  end

  it 'parses a valid v3 file name correctly' do
    path = audio_original.possible_paths_file(opts, original_file_name_v3)

    path_info = audio_original.parse_file_path(path[0])

    expect(path.size).to eq 1
    expect(path.first).to eq("#{BawWorkers::Config.original_audio_helper.possible_dirs[0]}/54/5498633d-89a7-4b65-8f4a-96aa0c09c619.mp3")

    expect(path_info[:uuid]).to eq uuid
    expect(path_info[:original_format]).to eq original_format
  end

  it 'parses a valid v1 file name correctly' do
    path = audio_original.possible_paths_file(opts, original_file_name_v1)

    path_info = audio_original.parse_file_path(path[0])

    expect(path.size).to eq 1
    expect(path.first).to eq("#{BawWorkers::Config.original_audio_helper.possible_dirs[0]}/54/5498633d-89a7-4b65-8f4a-96aa0c09c619_120302-1505.mp3")

    expect(path_info.keys.size).to eq 3
    expect(path_info[:uuid]).to eq uuid
    expect(path_info[:datetime_with_offset]).to eq datetime.change(sec: 0)
    expect(path_info[:original_format]).to eq original_format
  end

  it 'correctly enumerates no files in an empty storage directory' do
    files = []
    audio_original.existing_files do |file| files.push(file) end

    expect(files).to be_empty
  end

  it 'enumerates all files in the storage directory' do
    paths = audio_original.possible_paths(opts)
    paths.each do |path|
      FileUtils.mkpath(File.dirname(path))
      FileUtils.touch(path)
    end

    files = []
    audio_original.existing_files do |file|
      info = audio_original.parse_file_path(file)
      files.push(info.merge(file:))
    end

    aggregate_failures do
      expect(files.size).to eq(3)

      expect(files[0][:uuid]).to eq(uuid)
      expect(files[1][:uuid]).to eq(uuid)
      expect(files[2][:uuid]).to eq(uuid)

      expect(files[0][:original_format]).to eq(original_format)
      expect(files[1][:original_format]).to eq(original_format)
      expect(files[2][:original_format]).to eq(original_format)
    end
  end
end
