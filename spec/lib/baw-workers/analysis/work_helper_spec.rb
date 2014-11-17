require 'spec_helper'

describe BawWorkers::Analysis::WorkHelper do
  include_context 'shared_test_helpers'

  let(:work_helper) {

    BawWorkers::Analysis::WorkHelper.new(
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
    result = work_helper.run(
        {
            command_format: '%{program_name} %{analysis_type} -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}',
            uuid: '00' + 'a' * 34,
            program_name: 'time',
            analysis_type: 'analysis_type',
            source_file: 'source_file',
            config_file: 'config_file',
            output_dir: 'output_dir',
            temp_dir: 'temp_dir'
        })
    expect(result).to_not be_blank
    expect(result.to_json).to include('_cached_analysis_jobs/00/00aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
  end

end