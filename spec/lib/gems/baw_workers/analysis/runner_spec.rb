# frozen_string_literal: true

require 'workers_helper'

describe BawWorkers::Analysis::Runner do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  before(:each) do
    copy_test_programs
  end

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
    expect { runner.prepare({}) }.to raise_error(ArgumentError, /Hash must not be blank\./)
  end

  it 'has parameters' do
    analysis_params = {
      command_format: '<{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      config: 'blah',
      file_executable: 'echo',
      copy_paths: [],

      uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
      id: 123_456,
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

    prepared_opts = runner.prepare(analysis_params)

    # check started file exists
    started_file = File.join(prepared_opts[:dir_output], BawWorkers::Analysis::Runner::FILE_WORKER_STARTED)
    expect(File.exist?(started_file)).to be_truthy

    result = runner.execute(prepared_opts, analysis_params)

    expected_1 = 'z/programs/echo \"analysis_type -source '
    expected_2 = '/baw-server/tmp/_test_original_audio/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e_20141118-160500Z.wav -config '
    expected_3 = 'z/run.config -output '
    expected_4 = '/baw-server/tmp/_test_analysis_results/15/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e -tempdir '
    expected_5 = 'z/temp'
    expected_6 = '/runs/15_123456_'

    result_string = result.to_s
    expect(result_string).to include(expected_1)
    expect(result_string).to include(expected_2)
    expect(result_string).to include(expected_3)
    expect(result_string).to include(expected_4)
    expect(result_string).to include(expected_5)
    expect(result_string).to include(expected_6)

    expect(result).to_not be_blank

    result_json = result.to_json
    expect(result_json).to include('_analysis_results/15/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e')
    expect(result_json).to include('z/temp')
    expect(result_json).to include('analysis_type -source \\u003C{file_source}\\u003E -config \\u003C{file_config}\\u003E -output \\u003C{dir_output}\\u003E -tempdir \\u003C{dir_temp}\\u003E')
    expect(result_json).to include(analysis_params[:original_format])
  end

  it 'creates analysis failure file' do
    analysis_params = {
      command_format: '<{file_executable}> @QW#&%^@#&*%^(@#*& "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"',
      config: 'blah',
      file_executable: 'echo',
      copy_paths: [],

      uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
      id: 123_456,
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

    prepared_opts = runner.prepare(analysis_params)

    # check started file exists
    started_file = File.join(prepared_opts[:dir_output], BawWorkers::Analysis::Runner::FILE_WORKER_STARTED)
    expect(File.exist?(started_file)).to be_truthy

    runner.execute(prepared_opts, analysis_params)

    # check started file does not exist
    started_file = File.join(prepared_opts[:dir_output], BawWorkers::Analysis::Runner::FILE_WORKER_STARTED)
    expect(File.exist?(started_file)).to be_falsey

    # check executable failure file exists
    executable_fail_file = File.join(prepared_opts[:dir_output], BawWorkers::Analysis::Runner::FILE_EXECUTABLE_FAILURE)
    expect(File.exist?(executable_fail_file)).to be_truthy

  end

end
