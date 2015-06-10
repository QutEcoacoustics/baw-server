require 'spec_helper'

describe BawWorkers::Analysis::Action do
  include_context 'shared_test_helpers'

  let(:queue_name) { BawWorkers::Settings.actions.analysis.queue }

  let(:analysis_params) {
    {
        command_format: '%{executable_program} "analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}"',
        config_file: 'blah',
        executable_program: 'echo',

        uuid: 'f7229504-76c5-4f88-90fc-b7c3f5a8732e',
        id: 123456,
        datetime_with_offset: '2014-11-18T16:05:00Z',
        original_format: 'wav',

        job_id: 20,
        sub_folders: ['hello', 'here_i_am']
    }
  }

  let(:analysis_query) {
    {analysis_params: analysis_params}
  }

  let(:analysis_query_normalised) { BawWorkers::ResqueJobId.normalise(analysis_query) }

  let(:analysis_params_id) { BawWorkers::ResqueJobId.create_id_props(BawWorkers::Analysis::Action, analysis_query)}

  let(:expected_payload) {
    {
        "class" => "BawWorkers::Analysis::Action",
        "args" => [
            analysis_params_id,
            {
                "analysis_params"=>
                    {
                        "command_format"=>
                            "%{executable_program} \"analysis_type -source %{source_file} -config %{config_file} -output %{output_dir} -tempdir %{temp_dir}\"",
                        "uuid"=>"f7229504-76c5-4f88-90fc-b7c3f5a8732e",
                        "job_id"=>20,
                        "sub_folders"=>['hello', 'here_i_am'],
                        "datetime_with_offset"=>"2014-11-18T16:05:00Z",
                        "original_format"=>"wav",
                        "config_file"=>"blah", "id"=>123456,
                        "executable_program"=>"echo"
                    }
            }
        ]
    }
  }

  context 'queues' do

    it 'works on the analysis queue' do
      expect(Resque.queue_from_class(BawWorkers::Analysis::Action)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)

      result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      result2 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(result1)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      result3 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(result1)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end

    it 'can retrieve the job' do


      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(false)

      result1 = BawWorkers::Analysis::Action.action_enqueue(analysis_params)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Analysis::Action, analysis_query)).to eq(true)

      found = BawWorkers::ResqueApi.jobs_of_with(BawWorkers::Analysis::Action, analysis_query)

      job_id = BawWorkers::ResqueJobId.create_id_props(BawWorkers::Analysis::Action, analysis_query)
      # status = Resque::Plugins::Status::Hash.get(job_id)

      status = BawWorkers::Analysis::Action.get_job_status(analysis_params)

      expect(found.size).to eq(1)
      expect(found[0]['class']).to eq(BawWorkers::Analysis::Action.to_s)
      expect(found[0]['queue']).to eq(queue_name)
      expect(found[0]['args'].size).to eq(2)
      expect(found[0]['args'][0]).to eq(job_id)
      expect(found[0]['args'][1]).to eq(analysis_query_normalised)

      expect(job_id).to_not be_nil

      expect(status.status ).to eq('queued')
      expect(status.uuid ).to eq(job_id)
      expect(status.options ).to eq(analysis_query_normalised)

    end

  end

  it 'successfully runs an analysis on a file' do

    # create file
    possible_path_params = analysis_params.dup
    possible_path_params[:datetime_with_offset] = Time.zone.parse(possible_path_params[:datetime_with_offset])

    target_file = audio_original.possible_paths(possible_path_params)[1]
    FileUtils.mkpath(File.dirname(target_file))
    FileUtils.cp(audio_file_mono, target_file)

    FileUtils.mkpath(BawWorkers::Settings.paths.working_dir)

    FileUtils.cp('/bin/echo', File.join(BawWorkers::Settings.paths.working_dir,'echo'))

    result = BawWorkers::Analysis::Action.action_perform(analysis_params)

    expected_1 = '/baw-workers/tmp/custom_temp_dir/working/echo \"analysis_type -source '
    expected_2 = '/baw-workers/tmp/custom_temp_dir/_original_audio/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e_20141118-160500Z.wav -config '
    expected_3 = '/baw-workers/tmp/custom_temp_dir/working/blah -output '
    expected_4 = '/baw-workers/tmp/custom_temp_dir/_cached_analysis_jobs/20/f7/f7229504-76c5-4f88-90fc-b7c3f5a8732e/hello/here_i_am -tempdir '
    expected_5 = '/baw-workers/tmp/custom_temp_dir/temp/f7229504-76c5-4_'

    result_string = result.to_s
    expect(result_string).to include(expected_1)
    expect(result_string).to include(expected_2)
    expect(result_string).to include(expected_3)
    expect(result_string).to include(expected_4)
    expect(result_string).to include(expected_5)
  end

end