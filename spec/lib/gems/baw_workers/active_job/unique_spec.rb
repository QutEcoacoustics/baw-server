# frozen_string_literal: true

describe BawWorkers::ActiveJob::Unique do
  context 'when including' do
    before do
      # get a copy of the class that is unmodified from the rails initializers
      original = ::ActiveJob::Base.const_get(:ACTIVE_JOB_BASE_BACKUP)
      stub_const('::ActiveJob::Base', original.clone)
    end

    # I have tried multiple ways of cracking this nut, this is the only one that works for both include and prepend!
    let(:crude_spy) do
      unless BawWorkers::ActiveJob::Unique::ClassMethods.private_instance_methods.include?(:unique_setup)
        throw 'cannot find unique_setup method'
      end

      Module.new do
        private

        def unique_setup
          throw :spied
        end
      end
    end

    specify 'we are working with an unmodified ::ActiveJob::Base' do
      expect(::ActiveJob::Base.ancestors).not_to include(BawWorkers::ActiveJob::Unique)
    end

    context 'when included' do
      it 'calls :unique_setup' do
        ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)
        stub_const('BawWorkers::ActiveJob::Unique::ClassMethods', crude_spy)

        expect {
          ActiveJob::Base.include(BawWorkers::ActiveJob::Unique)
        }.to throw_symbol(:spied)
      end

      it 'succeeds when included without identity' do
        ::ActiveJob::Base.include(BawWorkers::ActiveJob::Unique)
      end
    end

    context 'when prepended' do
      it 'calls :unique_setup' do
        ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)

        stub_const('BawWorkers::ActiveJob::Unique::ClassMethods', crude_spy)

        expect {
          ActiveJob::Base.prepend(BawWorkers::ActiveJob::Unique)
        }.to throw_symbol(:spied)
      end

      it 'succeeds when prepended without identity' do
        ::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Unique)
      end
    end
  end

  describe 'uniqueness is checked before queueing' do
    pause_all_jobs
    ignore_pending_jobs

    before do
      @first_job = Fixtures::BasicJob.perform_later!(('first_id'))
    end

    it 'fails to enqueue a job with same id (enqueue)' do
      second_job = Fixtures::BasicJob.new('first_id')
      result = second_job.enqueue
      expect(result).to eq false
      expect(second_job.job_id).to eq 'Fixtures::BasicJob:first_id'
      expect(second_job.unique?).to eq false
    end

    it 'perform_later with a block is not allowed in application jobs' do
      expect {
        Fixtures::BasicJob.perform_later do
          puts 'i\'m a block and i\'m ok'
        end
      }.to raise_error(RuntimeError, 'perform_later does not support blocks')
    end

    it 'fails to enqueue a job with same id (perform_later)' do
      result = Fixtures::BasicJob.perform_later('first_id')
      expect(result).to eq false
    end

    it 'fails to enqueue a job with same id (perform_later!)' do
      job_id_from_block = nil
      unique_from_block = nil
      expect {
        Fixtures::BasicJob.perform_later!('first_id') do |job|
          job_id_from_block = job.job_id
          unique_from_block = job.unique?
        end
      }.to raise_error(BawWorkers::ActiveJob::EnqueueError, 'job with id Fixtures::BasicJob:first_id failed to enqueue')

      expect(job_id_from_block).to eq 'Fixtures::BasicJob:first_id'
      expect(unique_from_block).to eq false
    end

    it 'fails to enqueue a job with same id (try_perform_later)' do
      second_job = Fixtures::BasicJob.try_perform_later('first_id')
      expect(second_job).to be_an_instance_of(::Dry::Monads::Failure)
      expect {
        second_job.value!
      }.to raise_error(::Dry::Monads::UnwrapError)
      expect(second_job.failure.job_id).to eq 'Fixtures::BasicJob:first_id'
      expect(second_job.failure.unique?).to eq false
    end
  end

  context 'with unique jobs it does not interfere' do
    [
      ['enqueue', -> { Fixtures::BasicJob.new('another_id').enqueue }],
      ['perform_later', -> { Fixtures::BasicJob.perform_later('another_id') }],
      ['perform_later!', -> { Fixtures::BasicJob.perform_later!('another_id') }],
      ['try_perform_later', -> { Fixtures::BasicJob.try_perform_later('another_id').value! }]
    ].each do |name, block|
      it "enqueues jobs with different ids (#{name})" do
        result = block.call
        expect(result).to be_an_instance_of(Fixtures::BasicJob)
        expect(result.unique?).to eq true

        clear_pending_jobs
      end
    end
  end

  context 'with terminal jobs, they are not considered unique' do
    before do
      first_job = Fixtures::BasicJob.perform_later!(('first_id'))
      perform_jobs(count: 1)
      first_job.refresh_status!
      expect(first_job.status).to be_completed
    end

    [
      ['enqueue', -> { Fixtures::BasicJob.new('another_id').enqueue }],
      ['perform_later', -> { Fixtures::BasicJob.perform_later('another_id') }],
      ['perform_later!', -> { Fixtures::BasicJob.perform_later!('another_id') }],
      ['try_perform_later', -> { Fixtures::BasicJob.try_perform_later('another_id').value! }]
    ].each do |name, block|
      it "will allow terminal jobs to be run (#{name})" do
        result = block.call
        expect(result).to be_an_instance_of(Fixtures::BasicJob)
        expect(result.unique?).to eq true

        clear_pending_jobs
      end
    end
  end
end
