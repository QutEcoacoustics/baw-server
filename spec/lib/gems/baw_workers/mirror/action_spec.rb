# frozen_string_literal: true



describe BawWorkers::Mirror::Action do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  # we want to control the execution of jobs for this set of tests,
  # so change the queue name so the test worker does not
  # automatically process the jobs
  before(:each) do
    default_queue = Settings.actions.mirror.queue

    allow(Settings.actions.mirror).to receive(:queue).and_return(default_queue + '_manual_tick')

    # cleanup resque queues before each test
    BawWorkers::ResqueApi.clear_queue(default_queue)
    BawWorkers::ResqueApi.clear_queue(Settings.actions.mirror.queue)
  end

  let(:queue_name) { Settings.actions.mirror.queue }

  let(:mirror_source) { audio_file_mono.to_s }
  let(:mirror_dest) {
    [
      File.join(custom_temp, 'mirror_test_1.ogg'),
      File.join(custom_temp, 'mirror_test_2.ogg')
    ]
  }

  let(:mirror_params) {
    {
      'source' => mirror_source,
      'destinations' => mirror_dest
    }
  }

  let(:mirror_params_id) { BawWorkers::ResqueJobIdBROKEN!!!.create_id_props(BawWorkers::Mirror::Action, mirror_params) }

  let(:expected_payload) {
    {
      'class' => 'BawWorkers::Mirror::Action',
      'args' => [
        mirror_params_id,
        mirror_params
      ]
    }
  }

  context 'queues' do
    it 'works on the mirror queue' do
      expect(Resque.queue_from_class(BawWorkers::Mirror::Action)).to eq(queue_name)
    end

    it 'can enqueue' do
      result = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      expect(Resque.size(queue_name)).to eq(1)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
    end

    it 'has a sensible name' do
      allow(BawWorkers::Mirror::Action).to receive(:action_perform).and_return('an invalid mock value')

      unique_key = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Mirror::Action.queue)
      status = BawWorkers::ResqueApi.status_by_key(unique_key)

      expected = "Mirroring: from=#{mirror_source}, to=#{mirror_dest}"
      expect(status.name).to eq(expected)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      queued_query = { source: mirror_source, destinations: mirror_dest }

      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(false)

      result1 = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)

      result2 = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result2).to eq(nil)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)

      result3 = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result3).to eq(nil)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)

      actual = Resque.peek(queue_name)
      expect(actual).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(1)

      popped = Resque.pop(queue_name)
      expect(popped).to include(expected_payload)
      expect(Resque.size(queue_name)).to eq(0)
    end

    it 'can retrieve the job' do
      queued_query = { source: mirror_source, destinations: mirror_dest }
      queued_query_normalised = BawWorkers::ResqueJobIdBROKEN!!!.normalise(queued_query)

      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(false)

      result1 = BawWorkers::Mirror::Action.action_enqueue(mirror_source, mirror_dest)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Mirror::Action, queued_query)).to eq(true)

      found = BawWorkers::ResqueApi.jobs_of_with(BawWorkers::Mirror::Action, queued_query)

      job_id = BawWorkers::ResqueJobIdBROKEN!!!.create_id_props(BawWorkers::Mirror::Action, queued_query)
      # status = Resque::Plugins::Status::Hash.get(job_id)

      status = BawWorkers::Mirror::Action.get_job_status(mirror_source, mirror_dest)

      expect(found.size).to eq(1)
      expect(found[0]['class']).to eq(BawWorkers::Mirror::Action.to_s)
      expect(found[0]['queue']).to eq(queue_name)
      expect(found[0]['args'].size).to eq(2)
      expect(found[0]['args'][0]).to eq(job_id)
      expect(found[0]['args'][1]).to eq(queued_query_normalised)

      expect(job_id).to_not be_nil

      expect(status.status).to eq('queued')
      expect(status.uuid).to eq(job_id)
      expect(status.options).to eq(queued_query_normalised)
    end
  end

  it 'successfully mirrors a file' do
    expect(File.file?(mirror_source)).to be_truthy

    mirror_dest.each do |path|
      File.delete path if File.exist? path
    end

    expect(File.file?(mirror_dest[0])).to be_falsey
    expect(File.file?(mirror_dest[1])).to be_falsey

    result = BawWorkers::Mirror::Action.action_perform(mirror_source, mirror_dest)

    expect(result).to eq(mirror_dest)

    expect(File.file?(mirror_source)).to be_truthy
    expect(File.file?(mirror_dest[0])).to be_truthy
    expect(File.file?(mirror_dest[1])).to be_truthy

    file_size = File.size(mirror_source)
    file_audio_info = BawWorkers::Config.file_info.audio_info(mirror_source)

    expect(File.size(mirror_dest[0])).to eq(file_size)
    expect(File.size(mirror_dest[1])).to eq(file_size)

    dest_1 = file_audio_info
    dest_1[:file] = mirror_dest[0]
    expect(BawWorkers::Config.file_info.audio_info(mirror_dest[0])).to eq(dest_1)

    dest_2 = file_audio_info
    dest_2[:file] = mirror_dest[1]
    expect(BawWorkers::Config.file_info.audio_info(mirror_dest[1])).to eq(dest_2)
  end
end
