# frozen_string_literal: true



describe 'Resque::Plugins::Status' do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  before(:each) do
    BawWorkers::ResqueApi.clear_queue(BawWorkers::Template::Action.queue)
  end

  # We had a bug were configs were not initializing expire_in for resque status.
  # This test ensures that it is set.
  # These tests also test the monkey patch in `resque_status_custom_expire.rb` exists
  context 'expire_in tests' do
    it 'ensures expire_in is set for worker init' do
      # run is called in the test initialization in `spec_helper.rb`

      expect(Resque::Plugins::Status::Hash.expire_in).to eq(86_400)
    end

    it 'ensures expire_in is set for worker init' do
      # clear settings already loaded
      Resque::Plugins::Status::Hash.expire_in = nil

      expect(Resque::Plugins::Status::Hash.expire_in).to eq(nil)

      BawWorkers::Config.run_web(
        BawWorkers::Config.logger_worker,
        BawWorkers::Config.logger_mailer,
        BawWorkers::Config.logger_worker,
        BawWorkers::Config.logger_audio_tools,
        Settings
      )

      expect(Resque::Plugins::Status::Hash.expire_in).to eq(86_400)
    end

    it 'ensures our monkey patch exists' do
      expect(Resque::Plugins::Status::EXPIRE_STATUSES).to eq([
        'completed',
        'failed',
        'killed'
      ])
    end

    # Our monkey patch override the default TTL behaviour.
    # Normally the TTL is reset every status change.
    # Out patch makes sure the TTL is only set when a finished status has occurred.
    it 'ensures a TTL is in fact set on a resque:status key only after it has completed ' do
      # This is a just a copy of of a generic mirror test.
      # We are just interjecting a few extra assertions during the different stages of  the job to make sure
      # the resque:status keys are behaving as desired.

      # setup
      queue_name = 'template_default'

      payload = { test_payload: 'a value' }
      payload_wrapped = { template_params: { test_payload: 'a value' } }
      payload_normalised = BawWorkers::ResqueJobIdBROKEN!!!.normalise(payload_wrapped)

      # check before
      expect(Resque.size(queue_name)).to eq(0)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Template::Action, payload)).to eq(false)
      expect(Resque.enqueued?(BawWorkers::Template::Action, payload)).to eq(false)

      # queue and check
      result1 = BawWorkers::Template::Action.action_enqueue(payload)
      expect(Resque.size(queue_name)).to eq(1)
      expect(result1).to be_a(String)
      expect(result1.size).to eq(32)
      expect(BawWorkers::ResqueApi.job_queued?(BawWorkers::Template::Action, payload_wrapped)).to eq(true)
      expect(Resque.enqueued?(BawWorkers::Template::Action, payload_wrapped)).to eq(true)

      found = BawWorkers::ResqueApi.jobs_of_with(BawWorkers::Template::Action, payload_wrapped)
      job_id = BawWorkers::ResqueJobIdBROKEN!!!.create_id_props(BawWorkers::Template::Action, payload_wrapped)

      # check the contents of the resque payload
      expect(found.size).to eq(1)
      expect(found[0]['class']).to eq(BawWorkers::Template::Action.to_s)
      expect(found[0]['queue']).to eq(queue_name)
      expect(found[0]['args'].size).to eq(2)
      expect(found[0]['args'][0]).to eq(job_id)
      expect(found[0]['args'][1]).to eq(payload_normalised)

      expect(job_id).to_not be_nil

      # get status, ensure ttl is -1
      status = BawWorkers::ResqueApi.status_by_key(result1)
      expect(status.status).to eq('queued')
      expect(status.uuid).to eq(job_id)
      expect(status.options).to eq(payload_normalised)
      expect(BawWorkers::ResqueApi.status_ttl(result1)).to eq(-1)

      # dequeue and run the job
      was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Template::Action.queue)
      expect(was_run).to eq(true)

      # should also be able to retrieve status by uuid
      status = BawWorkers::ResqueApi.status_by_key(result1)

      expect(status).to_not be_nil
      expect(status.status).to eq('completed')
      expect(status.uuid).to eq(job_id)
      expect(status.uuid).to eq(result1)
      expect(status.options).to eq(payload_normalised)
      expect(BawWorkers::ResqueApi.status_ttl(result1)).to eq(86_400)
    end
  end

  # Tests that sensible names are part our base action's definition.
  # See https://github.com/QutBioacoustics/baw-workers/issues/41
  context 'sensible names' do
    it 'ensures action base has a name method that throws' do
      new_base = BawWorkers::ActionBase.new('imtotesauuidbro', im_an_option: :options!)

      expect {
        new_base.name
      }.to raise_error(NotImplementedError)
    end

    it 'allows for empty names' do
      allow_any_instance_of(BawWorkers::Template::Action).to receive(:name).and_return(nil)
      payload = { im_an_option: :options! }

      unique_key = BawWorkers::Template::Action.action_enqueue(payload)
      was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Template::Action.queue)
      status = BawWorkers::ResqueApi.status_by_key(unique_key)

      expect(status.name).to eq(nil)
    end

    it 'allows for duplicate names' do
      allow_any_instance_of(BawWorkers::Template::Action).to receive(:name).and_return('same_name')

      (1..2).each do |index|
        # technically a different job so resque solo should not complain
        payload = { im_an_option: index }

        unique_key = BawWorkers::Template::Action.action_enqueue(payload)
        was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Template::Action.queue)
        status = BawWorkers::ResqueApi.status_by_key(unique_key)

        expect(status.name).to eq('same_name')
      end
    end

    it 'names can reuse the uuid' do
      payload = { im_an_option: :options! }

      unique_key = BawWorkers::Template::Action.action_enqueue(payload)
      was_run = ResqueHelpers::Emulate.resque_worker(BawWorkers::Template::Action.queue)
      status = BawWorkers::ResqueApi.status_by_key(unique_key)

      expect(status.name).to eq('template:' + unique_key)
    end
  end
end
