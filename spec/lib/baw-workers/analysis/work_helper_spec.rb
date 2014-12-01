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
        command_format: '%{executable_program} "analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}"',
        uuid: '00' + 'a' * 34,
        datetime_with_offset: '2014-11-18T16:05:00Z',
        original_format: 'wav',
        config_file: 'blah',
        id: 123456,
        executable_program: ' echo'
    }

    # create file
    possible_path_params = analysis_params.dup
    possible_path_params[:datetime_with_offset] = Time.zone.parse(possible_path_params[:datetime_with_offset])

    target_file = audio_original.possible_paths(possible_path_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    FileUtils.mkpath(BawWorkers::Settings.paths.working_dir)

    result = nil
    expect {
      result = work_helper.run(analysis_params)
    }.to raise_error(BawAudioTools::Exceptions::AudioToolError, /echo "analysis_type \-source/)

    # expect(result).to_not be_blank
    # expect(result.to_json).to include('_cached_analysis_jobs/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    # expect(result.to_json).to include('/tmp/custom_temp_dir/temp/00aaa')
    # expect(result.to_json).to include('analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}')
    # expect(result.to_json).to include(analysis_params[:original_format])
  end

end