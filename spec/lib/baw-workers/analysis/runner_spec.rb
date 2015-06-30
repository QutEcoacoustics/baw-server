require 'spec_helper'

describe BawWorkers::Analysis::Runner do
  include_context 'shared_test_helpers'

  let(:runner) {
    BawWorkers::Analysis::Runner.new(
        audio_original,
        analysis_cache,
        BawWorkers::Config.logger_worker,
        BawWorkers::Config.worker_top_dir,
        BawWorkers::Config.programs_dir
    )
  }

  after(:each) do
    FileUtils.rm_rf(BawWorkers::Settings.paths.cached_analysis_jobs)
  end

  it 'prepare has no parameters' do
    expect { runner.prepare }.to raise_error(ArgumentError, /Hash must not be blank\./)
  end

  it 'has parameters' do
    analysis_params = {
        command_format: '%{file_executable} "analysis_type -source %{file_source} -config %{dir_output} -output %{dir_run} -tempdir %{dir_temp}"',
        config: 'blah',
        file_executable: 'echo',
        copy_paths: [],

        uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
        id: 123456,
        datetime_with_offset: '2014-11-18T16:05:00Z',
        original_format: 'wav',

        job_id: 15,
        sub_folders: ['something', 'another']
    }

    # create file
    possible_path_params = analysis_params.dup
    possible_path_params[:datetime_with_offset] = Time.zone.parse(possible_path_params[:datetime_with_offset])

    target_file = audio_original.possible_paths(possible_path_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    FileUtils.mkpath(BawWorkers::Settings.paths.working_dir)

    FileUtils.cp('/bin/echo', File.join(BawWorkers::Settings.paths.working_dir,'echo'))

    prepared_opts = runner.prepare(analysis_params)
    result = runner.execute(prepared_opts, analysis_params)

    expected_1 = '/baw-workers/tmp/custom_temp_dir/working/echo \"analysis_type -source '
    expected_2 = '/baw-workers/tmp/custom_temp_dir/_original_audio/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e_20141118-160500Z.wav -config '
    expected_3 = '/baw-workers/tmp/custom_temp_dir/working/blah -output '
    expected_4 = '/baw-workers/tmp/custom_temp_dir/_cached_analysis_jobs/15/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e/something/another -tempdir '
    expected_5 = '/baw-workers/tmp/custom_temp_dir/temp/f7229504-76c5-4_'

    result_string = result.to_s
    expect(result_string).to include(expected_1)
    expect(result_string).to include(expected_2)
    expect(result_string).to include(expected_3)
    expect(result_string).to include(expected_4)
    expect(result_string).to include(expected_5)

    expect(result).to_not be_blank

    result_json = result.to_json
    expect(result_json).to include('_cached_analysis_jobs/15/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e/something/another')
    expect(result_json).to include('/tmp/custom_temp_dir/temp/f7229504-76c5-4')
    expect(result_json).to include('analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}')
    expect(result_json).to include(analysis_params[:original_format])
  end

end