require 'spec_helper'

describe BawWorkers::AudioCheck::CsvHelper do
  include_context 'shared_test_helpers'

  let(:audio_original) { BawWorkers::Config.original_audio_helper }

  let(:uuid) { '5498633d-89a7-4b65-8f4a-96aa0c09c619' }
  let(:original_format) { 'mp3' }

  it 'can compare csv file and audio files' do
    csv_file = copy_test_audio_check_csv

    expected_intersection = []
    expected_files_without_db_entry = []
    expected_db_entries_without_file = []

    # create expected files
    is_utc_file_name = true
    excluded = nil
    BawWorkers::ReadCsv.read_audio_recording_csv(csv_file) do |audio_params|
      opts =
          {
              uuid: audio_params[:uuid],
              datetime_with_offset: BawWorkers::Validation.normalise_datetime(audio_params[:recorded_date]),
              original_format: audio_params[:original_format]

          }
      paths = audio_original.possible_paths(opts)

      if excluded.nil?
        # add utc file name by convention
        expected_db_entries_without_file.push(File.basename(paths[1]).downcase)
        excluded = opts.merge({paths: paths})
        next
      end

      # alternate between utc and +10 tz offset file names
      is_utc_file_name ? path = paths[1] : path = paths[0]

      FileUtils.mkpath(File.dirname(path))
      FileUtils.touch(path)
      expected_intersection.push(File.basename(path).downcase)

      is_utc_file_name = !is_utc_file_name
    end

    # create one additional file
    additional_file = audio_original.possible_paths(
        {
            uuid: uuid,
            datetime_with_offset: BawWorkers::Validation.normalise_datetime(Time.zone.now),
            original_format: original_format
        })[1]
    FileUtils.mkpath(File.dirname(additional_file))
    FileUtils.touch(additional_file)
    expected_files_without_db_entry.push(File.basename(additional_file).downcase)

    result = BawWorkers::AudioCheck::CsvHelper.compare_csv_db(csv_file)

    expect(result[:intersection].size).to eq(23)
    expect(result[:intersection]).to match_array(expected_intersection)

    expect(result[:files_without_db_entry].size).to eq(1)
    expect(result[:files_without_db_entry]).to match_array(expected_files_without_db_entry)

    expect(result[:db_entries_without_file].size).to eq(1)
    expect(result[:db_entries_without_file]).to match_array(expected_db_entries_without_file)
  end
end
