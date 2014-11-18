require 'spec_helper'

describe BawWorkers::Analysis::WorkHelper do
  include_context 'shared_test_helpers'

  let(:work_helper) {

    BawWorkers::Analysis::WorkHelper.new(
        audio_original,
        analysis_cache,
        BawWorkers::Config.logger_worker,
        custom_temp
    )
  }

  after(:each) do
    FileUtils.rm_rf(BawWorkers::Settings.paths.cached_analysis_jobs)
  end

  it 'has no parameters' do
    expect { work_helper.run }.to raise_error(ArgumentError, /Hash must not be blank\./)
  end

  it 'has parameters' do
    analysis_params = {
        command_format: 'ls -la analysis_type -source %{source_file} -config config_file -output %{output_dir} -tempdir %{temp_dir}',
        uuid: '00' + 'a' * 34,
        datetime_with_offset: Time.zone.parse('2014-11-18T16:05:00Z'),
        original_format: 'wav'
    }

    # create file
    target_file = audio_original.possible_paths(analysis_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    result = work_helper.run(analysis_params)
    expect(result).to_not be_blank
    expect(result.to_json).to include('_cached_analysis_jobs/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    expect(result.to_json).to include(analysis_params[:command_format])
    expect(result.to_json).to include(analysis_params[:original_format])
  end

end