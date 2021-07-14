# frozen_string_literal: true

describe BawWorkers::ActiveJob::Identity do
  before do
    # get a copy of the class that is unmodified from the rails initializers
    original = ::ActiveJob::Base.const_get(:ACTIVE_JOB_BASE_BACKUP)
    stub_const('::ActiveJob::Base', original.clone)
  end

  specify 'we are working with an unmodified ::ActiveJob::Base' do
    expect(::ActiveJob::Base.ancestors).not_to include(BawWorkers::ActiveJob::Identity)
  end

  it 'errors if included' do
    expect {
      Class.new do
        include BawWorkers::ActiveJob::Identity
      end
    }.to raise_error(TypeError, 'BawWorkers::ActiveJob::Identity must not be included. Try prepending.')
  end

  it 'errors if prepended in a class that does not inherit from active job' do
    expect {
      Class.new do
        prepend BawWorkers::ActiveJob::Identity
      end
    }.to raise_error(TypeError, /must be prepended in ActiveJob::Base/)
  end

  context 'without methods implemented for app jobs' do
    subject(:job_class) {
      FakeJob
    }

    before do
      stub_const('ApplicationJob', Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)))
      stub_const('FakeJob', Class.new(ApplicationJob))
    end

    it 'errors if name is not changed' do
      job_class.define_method(:create_job_id, -> { 'placeholder' })
      expect { job_class.new.name }.to raise_error NotImplementedError, 'You must implement name in your job class.'
    end

    it 'errors if job_id is not changed' do
      expect { job_class.new }.to raise_error NotImplementedError, 'You must implement create_job_id in your job class.'
    end
  end

  context 'without methods implemented for framework jobs' do
    subject(:job) {
      FakeJob.new
    }

    before do
      stub_const(
        'FakeJob',
        Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity))
      )
    end

    it 'generates a uuid name' do
      expect(job.name).to match /FakeJob:[-a-f0-9]{36}/
    end

    it 'generates a uuid job_id' do
      expect(job.job_id).to match /FakeJob:[-a-f0-9]{36}/
    end
  end

  context 'with a valid implementation' do
    subject(:job) {
      FakeJob.new('job arg is passed into job arguments')
    }

    before do
      stub_const('ApplicationJob', Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)))
      impl = Class.new(ApplicationJob) do
        def name
          "#{self.class.name}: fake job name for #{job_id}"
        end

        def create_job_id
          "abc123:#{arguments[0]}"
        end
      end
      stub_const('FakeJob', impl)
    end

    it 'generates a name' do
      expect(job.name).to eq('FakeJob: fake job name for abc123:jobargispassedintojobarguments')
    end

    it 'generates a job_id' do
      expect(job.job_id).to eq('abc123:jobargispassedintojobarguments')
    end
  end

  context 'with a valid implementation, with no arguments' do
    subject(:job) {
      FakeJob.new
    }

    before do
      stub_const('ApplicationJob', Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)))
      impl = Class.new(ApplicationJob) do
        def name
          "#{self.class.name}: fake job name for #{job_id}"
        end

        def create_job_id
          "abc123:#{arguments[0]}"
        end
      end
      stub_const('FakeJob', impl)
    end

    it 'generates a name' do
      expect(job.name).to eq('FakeJob: fake job name for abc123:')
    end

    it 'generates a job_id' do
      expect(job.job_id).to eq('abc123:')
    end
  end

  context 'with a implementation that produces keys with spaces' do
    subject(:job) {
      FakeJob.new('job arg is passed into job arguments')
    }

    before do
      stub_const('ApplicationJob', Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)))
      impl = Class.new(ApplicationJob) do
        def name
          "#{self.class.name}: fake job name for #{job_id}"
        end

        def create_job_id
          "abc123:#{arguments[0]}"
        end
      end
      stub_const('FakeJob', impl)
    end

    it 'generates a name' do
      expect(job.name).to eq('FakeJob: fake job name for abc123:jobargispassedintojobarguments')
    end

    it 'generates a job_id without spaces' do
      expect(job.job_id).to eq('abc123:jobargispassedintojobarguments')
    end
  end

  context 'when deserialized' do
    subject(:job) {
      FakeJob.new
    }

    before do
      stub_const('ApplicationJob', Class.new(::ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)))
      impl = Class.new(ApplicationJob) do
        def name
          "#{self.class.name}: fake job name for #{job_id}"
        end

        def create_job_id
          "abc123:#{arguments[0]}"
        end
      end
      stub_const('FakeJob', impl)
    end

    it 'has the she same name after deserialization' do
      data = job.serialize
      expect(data).to be_an_instance_of(Hash)

      job2 = FakeJob.deserialize(data)
      expect(job2).not_to eq job

      expect(job2.name).to eq job.name
    end
  end
end
