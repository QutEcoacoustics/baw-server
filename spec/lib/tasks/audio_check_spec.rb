require 'spec_helper'
require 'fakeredis'

describe 'baw:action:audio_check' do
  include_context 'media_file'
  include_context 'rake_tests'
  include_context 'rspect_output_files'

  context 'rake task' do

    it 'runs successfully standalone' do
      csv_file_example  = File.join(example_media_dir, 'audio_check.csv')
      csv_file = File.join(tmp_dir, '_audio_check_to_do.csv')
      FileUtils.cp(csv_file_example, csv_file)

      BawWorkers::AudioCheck::CsvHelper.read_audio_recording_csv(csv_file) do |audio_params|
        audio_params[:datetime_with_offset] = audio_params[:recorded_date]
        create_original_audio(audio_params, audio_file_mono, false)
        # FileUtils.touch(File.join(audio_original.possible_dirs[0], '83/837df827-2be2-43ef-8f48-60fa0ee6ad37_930712-1552.asf'))
      end

      run_rake_task('baw:action:audio_check:standalone:from_csv', default_settings_file)
    end

    it 'runs successfully using resque' do
      FileUtils.cp(File.join(example_media_dir, 'audio_check.csv'), File.join(tmp_dir, '_audio_check_to_do.csv'))
      run_rake_task('baw:action:audio_check:resque:from_csv', default_settings_file)
    end

  end
end