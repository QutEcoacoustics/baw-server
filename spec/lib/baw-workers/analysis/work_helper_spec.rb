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
        executable_program: 'echo'
    }

    # create file
    possible_path_params = analysis_params.dup
    possible_path_params[:datetime_with_offset] = Time.zone.parse(possible_path_params[:datetime_with_offset])

    target_file = audio_original.possible_paths(possible_path_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    FileUtils.mkpath(BawWorkers::Settings.paths.working_dir)

    FileUtils.cp('/bin/echo', File.join(BawWorkers::Settings.paths.working_dir,'echo'))

    result = work_helper.run(analysis_params)

    expected_1 = '/baw-workers/tmp/custom_temp_dir/working/echo \"analysis_type -source '
    expected_2 = '/baw-workers/tmp/custom_temp_dir/_original_audio/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa_20141118-160500Z.wav -config '
    expected_3 = '/baw-workers/tmp/custom_temp_dir/working/blah -output '
    expected_4 = '/baw-workers/tmp/custom_temp_dir/_cached_analysis_jobs/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -tempdir '
    expected_5 = '/baw-workers/tmp/custom_temp_dir/temp/00aaaaaaaaaaaaa_'

    result_string = result.to_s
    expect(result_string).to include(expected_1)
    expect(result_string).to include(expected_2)
    expect(result_string).to include(expected_3)
    expect(result_string).to include(expected_4)
    expect(result_string).to include(expected_5)

    expect(result).to_not be_blank

    result_json = result.to_json
    expect(result_json).to include('_cached_analysis_jobs/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
    expect(result_json).to include('/tmp/custom_temp_dir/temp/00aaa')
    expect(result_json).to include('analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}')
    expect(result_json).to include(analysis_params[:original_format])
  end

end