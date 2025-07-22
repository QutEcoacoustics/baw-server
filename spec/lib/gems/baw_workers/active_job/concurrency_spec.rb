# frozen_string_literal: true

require "#{RSPEC_ROOT}/fixtures/jobs.rb"

describe BawWorkers::ActiveJob::Concurrency, timeout: 60 do
  include_context Baw::Async::RSpec::Reactor

  def run_workers(count)
    # allow a little time for our real worker to dequeue
    sleep 0.5

    # then emulate additional workers
    barrier = Async::Barrier.new
    reactor.async do
      count.times do
        barrier.async do
          ResqueHelpers::Emulate.resque_worker(Fixtures::FIXTURE_QUEUE, true, false)
        end
      end
    end

    # don't need the task to finish
    @barrier = barrier

    # want time for the workers to start
    sleep 0.5
  end

  def cleanup(barrier)
    barrier.stop
    # wait for all workers to finish
    barrier.wait
  ensure
    ActiveRecord::Base.connection_pool.release_connection
  end

  after do
    cleanup(@barrier) if defined?(@barrier)
  end

  # Testing my understanding of ruby - we use ensure to decrement the
  # concurrency counter. Testing that it handles exceptions and throws.
  describe 'experiments' do
    it 'can ensure after a throw' do
      value = nil

      throw_value = catch('error') {
        begin
          throw 'error'
        ensure
          value = 'ensure'
        end

        123
      }

      expect(value).to eq('ensure')
      expect(throw_value).to be_nil
    end

    it 'ensures on an uncaught throw' do
      value = nil

      expect {
        begin
          throw 'error'
        ensure
          value = 'ensure'
        end
      }.to raise_error(UncaughtThrowError, /uncaught throw/)

      expect(value).to eq('ensure')
    end
  end

  it 'does not create a record for jobs that do not have a concurrency limit' do
    Fixtures::Concurrency::NormalJobClass.perform_now(1)

    expect_performed_jobs(1, of_class: Fixtures::Concurrency::NormalJobClass)

    key = BawWorkers::ActiveJob::Concurrency::Persistence.key_prefix(
      Fixtures::Concurrency::NormalJobClass.name,
      nil
    )

    expect(BawWorkers::ActiveJob::Concurrency::Persistence.redis.exists?(key)).to be false
  end

  it 'can increment and decrement a counter' do
    Fixtures::Concurrency::DiscardJobClass.perform_now(1)
  end

  [
    [Fixtures::Concurrency::DiscardJobClass, 1, :discard, nil],
    [Fixtures::Concurrency::MultipleJobClass, 2, :discard, nil],
    [Fixtures::Concurrency::RetryJobClass, 1, :retry, nil],
    [Fixtures::Concurrency::NormalJobClass, nil, nil, nil],
    [Fixtures::Concurrency::ParameterizedJobClass, 1, :discard, Proc]
  ].each do |tuple|
    it "can check concurrency limit is set #{tuple.first.name} on the class" do
      job_class, limit, on_limit, parameters_block = tuple
      expect(job_class.concurrency_limit).to eq limit
      expect(job_class.concurrency_action).to eq on_limit

      if parameters_block.nil?
        expect(job_class.concurrency_parameters).to be_nil
      else
        expect(job_class.concurrency_parameters).to be_an_instance_of Proc
      end
    end

    it "can check concurrency limit is set #{tuple.first.name} on the instance" do
      job_class, limit, on_limit, parameters_block = tuple

      # making a new instance of a job that does not get cleaned up will not
      # release it's connection from the database connection pool
      job = job_class.new(10)

      expect(job.concurrency_limit).to eq limit
      expect(job.concurrency_action).to eq on_limit

      if parameters_block.nil?
        expect(job.concurrency_parameters).to be_nil
      else
        expect(job.concurrency_parameters).to be_an_instance_of Proc
      end
    ensure
      ActiveRecord::Base.connection_pool.release_connection
    end
  end

  stepwise 'basic limit and discard' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::DiscardJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::DiscardJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::DiscardJobClass.perform_later!(20)
    end

    step 'run extra workers' do
      # start two additional workers, that each run one job then shut down
      run_workers(2)
    end

    step 'checks job 1 is still working' do
      expect(@j1.refresh_status!).to be_working
    end

    step 'checks jobs 2 and 3 failed' do
      expect(@j2.refresh_status!).to be_failed
      expect(@j3.refresh_status!).to be_failed
    end

    step 'checks job 2 and 3 failed because of concurrency limit' do
      expect(@j2.status.messages).to contain_exactly(
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::DiscardJobClass.*/,
        'The job was discarded: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::DiscardJobClass is registered by discard_on'
      )

      expect(@j3.status.messages).to contain_exactly(
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::DiscardJobClass.*/,
        'The job was discarded: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::DiscardJobClass is registered by discard_on'
      )
    end

    step 'there are no other jobs in the queue because the others were discarded' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency limit is still 1' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::DiscardJobClass.name,
        nil
      )).to eq 1
    end

    step 'resets count after job is finished' do
      @j1.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::DiscardJobClass.name,
        nil
      )).to eq 0

      expect(@j1.refresh_status!).to be_killed
    end
  end

  stepwise 'basic limit and retry' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::RetryJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::RetryJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::RetryJobClass.perform_later!(20)
    end

    step 'run extra workers' do
      # start two additional workers, that each run one job then shut down
      run_workers(2)
    end

    step 'checks job 1 is still working' do
      expect(@j1.refresh_status!).to be_working
    end

    step 'checks jobs 2 and 3 failed' do
      expect(@j2.refresh_status!).to be_queued
      expect(@j3.refresh_status!).to be_queued
    end

    step 'checks job 2 and 3 failed because of concurrency limit' do
      expect(@j2.status.messages).to contain_exactly(
        'Attempt 1',
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::RetryJobClass.*/,
        'Attempt 2'
      )

      expect(@j3.status.messages).to contain_exactly(
        'Attempt 1',
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::RetryJobClass.*/,
        'Attempt 2'
      )
    end

    step 'checks the failed jobs are in retry queue' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(2)
    end

    step 'checks the concurrency limit is still 1' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::RetryJobClass.name,
        nil
      )).to eq 1
    end

    step 'resets count after job is finished' do
      @j1.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::RetryJobClass.name,
        nil
      )).to eq 0

      expect(@j1.refresh_status!).to be_killed
    end
  end

  stepwise 'higher limit and discard' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::MultipleJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::MultipleJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::MultipleJobClass.perform_later!(20)
    end

    step 'run extra workers' do
      # start two additional workers, that each run one job then shut down
      run_workers(2)
    end

    step 'checks job 1 and 2 are still working' do
      expect(@j1.refresh_status!).to be_working
      expect(@j2.refresh_status!).to be_working
    end

    step 'checks job 3 is failed' do
      expect(@j3.refresh_status!).to be_failed
    end

    step 'checks job 3 failed because of concurrency limit' do
      expect(@j3.status.messages).to contain_exactly(
        /The job failed because of an error: Concurrency count 3 reached for limit 2 for Fixtures::Concurrency::MultipleJobClass.*/,
        'The job was discarded: Concurrency count 3 reached for limit 2 for Fixtures::Concurrency::MultipleJobClass is registered by discard_on'
      )
    end

    step 'there are no other jobs in the queue because the others were discarded' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency limit is still 2' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::MultipleJobClass.name,
        nil
      )).to eq 2
    end

    step 'resets count after job is finished' do
      @j1.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::MultipleJobClass.name,
        nil
      )).to eq 1

      expect(@j1.refresh_status!).to be_killed

      @j2.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::MultipleJobClass.name,
        nil
      )).to eq 0

      expect(@j2.refresh_status!).to be_killed
    end
  end

  stepwise 'faulty jobs reset counter' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::FaultyJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::FaultyJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::FaultyJobClass.perform_later!(20)
    end

    step 'run extra workers' do
      # start two additional workers, that each run one job then shut down
      run_workers(2)
    end

    step 'checks all jobs failed' do
      expect(@j1.refresh_status!).to be_failed
      expect(@j2.refresh_status!).to be_failed
      expect(@j3.refresh_status!).to be_failed
    end

    step 'checks jobs failed because of concurrency limit' do
      [@j1, @j2, @j3].each do |job|
        expect(job.status.messages).to contain_exactly(
          /.*I am faulty.*/,
          'The job was discarded: I am faulty is registered by discard_on'
        )
      end
    end

    step 'there are no other jobs in the queue because the others were discarded' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency limit is 0' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::FaultyJobClass.name,
        nil
      )).to eq 0
    end
  end

  stepwise 'job classes each have their own counter' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::DiscardJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::MultipleJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::MultipleJobClass.perform_later!(20)
      @j4 = Fixtures::Concurrency::RetryJobClass.perform_later!(20)
      @jobs = [@j1, @j2, @j3, @j4]
    end

    step 'run extra workers' do
      # start two additional workers, that each run one job then shut down
      run_workers(3)
    end

    step 'checks all jobs are still working' do
      expect(@jobs.map(&:refresh_status!)).to all(be_working)
    end

    step 'there are no other jobs in the queue because no concurrency limit was reached' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency count' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::DiscardJobClass.name,
        nil
      )).to eq 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::MultipleJobClass.name,
        nil
      )).to eq 2
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::RetryJobClass.name,
        nil
      )).to eq 1
    end

    step 'resets count after job is finished' do
      @jobs.each(&:mark_for_kill!)
      sleep 1

      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::DiscardJobClass.name,
        nil
      )).to eq 0
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::MultipleJobClass.name,
        nil
      )).to eq 0
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::RetryJobClass.name,
        nil
      )).to eq 0
    end
  end

  stepwise 'normal jobs are not affected' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::NormalJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::NormalJobClass.perform_later!(20)
      @j3 = Fixtures::Concurrency::NormalJobClass.perform_later!(20)
      @j4 = Fixtures::Concurrency::NormalJobClass.perform_later!(20)
      @jobs = [@j1, @j2, @j3, @j4]
    end

    step 'run extra workers' do
      run_workers(3)
    end

    step 'checks all jobs are still working' do
      expect(@jobs.map(&:refresh_status!)).to all(be_working)
    end

    step 'there are no other jobs in the queue because no concurrency limit was reached' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency count' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::NormalJobClass.name,
        nil
      )).to eq 0
    end

    step 'resets count after job is finished' do
      @jobs.each(&:mark_for_kill!)
      sleep 1

      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::NormalJobClass.name,
        nil
      )).to eq 0
    end
  end

  stepwise 'parameterized semaphores' do
    step 'make some jobs' do
      @j1 = Fixtures::Concurrency::ParameterizedJobClass.perform_later!(20)
      @j2 = Fixtures::Concurrency::ParameterizedJobClass.perform_later!(10)
      @j3 = Fixtures::Concurrency::ParameterizedJobClass.perform_later!(20)
      @j4 = Fixtures::Concurrency::ParameterizedJobClass.perform_later!(10)
    end

    step 'run extra workers' do
      # start additional workers, that each run one job then shut down
      run_workers(4)
    end

    step 'checks job 1 and 2 are still working' do
      expect(@j1.refresh_status!).to be_working
      expect(@j2.refresh_status!).to be_working
    end

    step 'checks job 3 and 4 are failed' do
      expect(@j3.refresh_status!).to be_failed
      expect(@j4.refresh_status!).to be_failed
    end

    step 'checks job 3 and 4 failed because of concurrency limit' do
      expect(@j3.status.messages).to contain_exactly(
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::ParameterizedJobClass:20.*/,
        'The job was discarded: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::ParameterizedJobClass:20 is registered by discard_on'
      )

      expect(@j4.status.messages).to contain_exactly(
        /The job failed because of an error: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::ParameterizedJobClass:10.*/,
        'The job was discarded: Concurrency count 2 reached for limit 1 for Fixtures::Concurrency::ParameterizedJobClass:10 is registered by discard_on'
      )
    end

    step 'there are no other jobs in the queue because the others were discarded' do
      expect_enqueued_jobs(0)
      expect_delayed_jobs(0)
    end

    step 'checks the concurrency limit is still 1 for 2 instances' do
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::ParameterizedJobClass.name, 10
      )).to eq 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::ParameterizedJobClass.name, 20
      )).to eq 1
    end

    step 'resets count after job is finished' do
      @j1.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::ParameterizedJobClass.name, 20
      )).to eq 0

      expect(@j1.refresh_status!).to be_killed

      @j2.mark_for_kill!
      sleep 1
      expect(BawWorkers::ActiveJob::Concurrency::Persistence.current_count(
        Fixtures::Concurrency::ParameterizedJobClass.name, 10
      )).to eq 0

      expect(@j2.refresh_status!).to be_killed
    end
  end
end
