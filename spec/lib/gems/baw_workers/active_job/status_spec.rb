# frozen_string_literal: true

require "#{RSPEC_ROOT}/fixtures/jobs.rb"

# rubocop:disable Rails/ActiveSupportOnLoad
describe BawWorkers::ActiveJob::Status do
  let(:persistence) { BawWorkers::ActiveJob::Status::Persistence }

  context 'when including' do
    before do
      # get a copy of the class that is unmodified from the rails initializers
      clone = ActiveJob::Base.const_get(:ACTIVE_JOB_BASE_BACKUP).clone
      stub_const('::ActiveJob::Base', clone)
    end

    # I have tried multiple ways of cracking this nut, this is the only one that works for both include and prepend!
    let(:crude_spy) do
      unless BawWorkers::ActiveJob::Status::ClassMethods.private_instance_methods.include?(:__status_setup)
        throw 'cannot find __status_setup method'
      end

      Module.new do
        private

        def __status_setup
          throw :spied
        end
      end
    end

    specify 'we are working with an unmodified ::ActiveJob::Base' do
      expect(ActiveJob::Base.ancestors).not_to include(BawWorkers::ActiveJob::Status)
    end

    context 'when included' do
      it 'calls :__status_setup' do
        ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)
        stub_const('BawWorkers::ActiveJob::Status::ClassMethods', crude_spy)

        expect {
          ActiveJob::Base.include(BawWorkers::ActiveJob::Status)
        }.to throw_symbol(:spied)
      end

      it 'succeeds when included without identity' do
        ActiveJob::Base.include(BawWorkers::ActiveJob::Status)
      end
    end

    context 'when prepended' do
      it 'calls :__status_setup' do
        ActiveJob::Base.prepend(BawWorkers::ActiveJob::Identity)

        stub_const('BawWorkers::ActiveJob::Status::ClassMethods', crude_spy)

        expect {
          ActiveJob::Base.prepend(BawWorkers::ActiveJob::Status)
        }.to throw_symbol(:spied)
      end

      it 'succeeds when prepended without identity' do
        ActiveJob::Base.prepend(BawWorkers::ActiveJob::Status)
      end
    end
  end

  describe 'create' do
    pause_all_jobs
    ignore_pending_jobs

    let!(:job) { Fixtures::BasicJob.perform_later!('creating') }

    it 'adds the job to the queue' do
      expect_enqueued_jobs(1)
      expect_enqueued_jobs(1, klass: Fixtures::BasicJob)
    end

    it 'adds the job_id to statuses' do
      expect(persistence.get_status_ids).to contain_exactly('Fixtures::BasicJob:creating')
    end

    it 'has our custom job id' do
      expect(job.job_id).to eq('Fixtures::BasicJob:creating')
    end

    it 'has a status object' do
      expect(job.status.to_h).to match(
        a_hash_including(
          job_id: 'Fixtures::BasicJob:creating',
          name: nil,
          status: BawWorkers::ActiveJob::Status::STATUS_QUEUED,
          messages: [],
          options: a_hash_including(arguments: ['creating']),
          progress: 0,
          total: 1
        )
      )
    end

    it 'has a TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix('Fixtures::BasicJob:creating'))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::PENDING_EXPIRE_IN)
    end

    it 'is not in the kill list' do
      expect(persistence.marked_for_kill_ids).to be_empty
    end
  end

  describe 'create fail cases' do
    it 'requires a string job_id' do
      job = Fixtures::BasicJob.new
      allow(job).to receive(:job_id).and_return(Object.new)

      expect {
        job.enqueue
      }.to raise_error(TypeError, /Invalid job_id/)
    end

    it 'removes a status if a callback further down the chain fails' do
      impl = Class.new(BawWorkers::Jobs::ApplicationJob) do
        before_enqueue { throw :abort }
        perform_expects
        def perform; end

        def name
          "#{self.class.name}: fake job name for #{job_id}"
        end

        def create_job_id
          "abc123:#{arguments[0]}"
        end
      end

      expect(persistence).to receive(:create).and_call_original
      expect(persistence).to receive(:remove).and_call_original
      result = impl.perform_later
      expect(result).to be false
      expect(persistence.get_status_ids).to be_empty
      expect(persistence.marked_for_kill_ids).to be_empty
    end

    it 'removes a status if enqueuing fails' do
      abort_fail_enqueue =  Fixtures::BasicJob.clone
      expect(abort_fail_enqueue.queue_adapter)
        .to receive(:enqueue)
        .and_raise(StandardError)

      expect(persistence).to receive(:create).and_call_original
      expect(persistence).to receive(:remove).and_call_original
      expect {
        abort_fail_enqueue.perform_later('don\'t create')
      }.to raise_error(StandardError)
      expect(persistence.get_status_ids).to be_empty
      expect(persistence.marked_for_kill_ids).to be_empty
    end

    it 'fails to enqueue if job_id contains a space' do
      expect {
        job = Fixtures::NeverQueuedJob.new('space in key')
        job.job_id = 'space in key'
        job.enqueue
      }.to raise_error(ArgumentError, 'job_id cannot contain a space')
    end
  end

  context 'when potential create race conditions occur' do
    pause_all_jobs
    it 'tries to be resilient' do
      # the basic flow goes:
      # job 1: is unique? yes
      # job 2: is unique? yes
      # job 2: enqueue
      # job 1: enqueue -> failure, can't create status again

      # simulate a race condition
      count = 10
      jobs = (1..count).map { |i| Fixtures::DuplicateJob.new('duplicate', i) }
      expect(jobs.length).to eq count

      allow(jobs[0]).to receive(:id_unique?).and_wrap_original do |_m, *_args|
        logger.warn 'not aborting'
        true
      end
      # ensure the second job does not abort, i.e. make it think it is unique
      allow(jobs[1]).to receive(:id_unique?).and_wrap_original do |_m, *_args|
        # add a little sleep here to ensure order of events are accurate
        logger.warn 'not aborting'
        true
      end
      futures = Concurrent::Promises.zip(
        *jobs.map { |j|
          Concurrent::Promises.delay {
            logger.warn 'enqueuing'
            j.enqueue
          }
        }
      )

      monitor_redis(io: $stdout) do
        futures.wait
      end

      results = futures.value!

      enqueue_aborts = count - 1

      expect(results).to contain_exactly(
        *([false] * enqueue_aborts),
        an_instance_of(Fixtures::DuplicateJob)
      )

      expect(jobs).to contain_exactly(
        *([having_attributes(unique?: false)] * enqueue_aborts),
        having_attributes(unique?: true)
      )
      expect_enqueued_jobs(1)

      clear_pending_jobs
    end
  end

  describe 'scheduled tasks' do
    pause_all_jobs
    ignore_pending_jobs

    let!(:job) { Fixtures::BasicJob.set(wait: 10 * 60).perform_later('later') }

    it 'does not add the job to the queue' do
      expect_enqueued_jobs(0)
      expect(persistence.redis.zcard('resque:delayed_queue_schedule')).to eq(1)
    end

    it 'adds the job_id to statuses' do
      expect(persistence.get_status_ids).to contain_exactly('Fixtures::BasicJob:later')
    end

    it 'has our custom job id' do
      expect(job.job_id).to eq('Fixtures::BasicJob:later')
    end

    it 'has a status object' do
      expect(job.status.to_h).to match(a_hash_including({
        job_id: 'Fixtures::BasicJob:later',
        name: nil,
        status: BawWorkers::ActiveJob::Status::STATUS_QUEUED,
        messages: [],
        options: a_hash_including(arguments: ['later']),
        progress: 0,
        total: 1
      }))
    end

    it 'has a TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix('Fixtures::BasicJob:later'))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::PENDING_EXPIRE_IN + 10.minutes.to_i)
    end

    it 'is not in the kill list' do
      expect(persistence.marked_for_kill_ids).to be_empty
    end
  end

  describe 'perform' do
    pause_all_jobs

    before do
      # create the job
      @job = Fixtures::WorkingJob.perform_later!('perform', 100)
      @commands = monitor_redis {
        perform_jobs(count: nil, timeout: 5)
      }
      @job.refresh_status!
    end

    it 'updated it\'s status to working' do
      expect(@commands).to include(/"get" "activejob:status:Fixtures::WorkingJob:perform"/)
      expect(@commands).to include(/"set" "activejob:status:Fixtures::WorkingJob:perform".*status.*working/)
    end

    it 'updated it\'s status with each tick' do
      expect(@commands).to include(/"set" "activejob:status:Fixtures::WorkingJob:perform".*status.*working/).at_least(100).times
      ticks = (1..100).map { |i| /At #{i}/ }
      expect(@commands).to include(*ticks)
      expect(@job.status.messages.count).to be >= 100
    end

    it 'updated it\'s status to complete' do
      expect(@commands).to include(/"set" "activejob:status:Fixtures::WorkingJob:perform".*status.*completed/)
      expect(@job.status).to be_completed
      expect(@job.status.messages).to include(/Completed at.*/)
    end

    it 'has terminal TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix(@job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'killable job' do
    pause_all_jobs

    let(:job) { Fixtures::KillableJob.perform_later!('die_job_die') }

    example 'the kill list has one job' do
      job.mark_for_kill!
      expect(persistence.redis.scard(persistence.kill_set)).to eq(1)
      expect(
        persistence.redis.sismember(
          persistence.kill_set,
          'Fixtures::KillableJob:die_job_die'
        )
      ).to be true

      clear_pending_jobs
    end

    it 'can kill the job when it is dequeued' do
      job.mark_for_kill!
      perform_jobs
      status = job.refresh_status!
      expect(status).to be_killed
      expect(status.messages).to contain_exactly(/Killed/, 'on kill called')
      # no jobs left to kill
      expect(persistence.redis.scard(persistence.kill_set)).to eq(0)
    end

    it 'can kill the job while it is working' do
      expect(persistence.redis.scard(persistence.kill_set)).to eq(0)
      perform_all_jobs_immediately do
        # dereference job from let to actually start it :-/
        job
        # give it a chance to dequeue and start working
        sleep 1

        job.mark_for_kill!
      end
      sleep(0.5)
      status = job.refresh_status!
      expect(status).to be_killed
      expect(status.messages).to include(/Killed/, 'on kill called')
      expect(status.messages).to include('At 0 of 100')
      expect(status.progress).to be > 0
      # no jobs left to kill
      expect(persistence.redis.scard(persistence.kill_set)).to eq(0)
    end

    it 'has terminal TTL' do
      job.mark_for_kill!
      perform_jobs(count: 1)
      ttl = persistence.redis.ttl(persistence.status_prefix(job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'fail job' do
    pause_all_jobs

    let(:job) { Fixtures::FailureJob.new('do_an_fail') }

    before do
      job.enqueue
      perform_jobs
      job.refresh_status!
      job
    end

    it 'has a status of failed' do
      expect(job.status).to be_failed
    end

    it 'has only failure messages' do
      expect(job.status.messages).to contain_exactly("I'm such a failure", 'on failure called')
    end

    it 'has terminal TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix(job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'error job' do
    pause_all_jobs

    let(:job) { Fixtures::ErrorJob.perform_later!('do_an_error') }

    before do
      #  dereference let
      job
      perform_jobs(wait_for_resque_failures: false)
      job.refresh_status!
    end

    it 'has a status of errored' do
      expect(job.status).to be_errored
    end

    it 'has only error messages' do
      expect(job.status.messages).to contain_exactly(
        /The job failed because of an error: I'm a bad little job at .*/,
        "on error called: I'm a bad little job"
      )
    end

    it 'has terminal TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix(job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'discarded job' do
    pause_all_jobs

    let(:job) { Fixtures::DiscardJob.perform_later!('do_an_discard') }

    before do
      #  dereference let
      job
      perform_jobs(wait_for_resque_failures: false)
      job.refresh_status!
    end

    it 'has a status of failed' do
      expect(job.status).to be_failed
    end

    it 'has only error messages' do
      expect(job.status.messages).to contain_exactly(
        /The job failed because of an error: should be discarded at .*/,
        /The job was discarded: .*/
      )
    end

    it 'has terminal TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix(job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'early completion job' do
    pause_all_jobs

    let(:job) { Fixtures::CompletedJob.perform_later!('do_an_early') }

    before do
      job
      perform_jobs
      job.refresh_status!
    end

    it 'has a status of completed' do
      expect(job.status).to be_completed
    end

    it 'has only completed messages' do
      expect(job.status.messages).to contain_exactly("I'm such a completionist", 'on completed called')
    end

    it 'has terminal TTL' do
      ttl = persistence.redis.ttl(persistence.status_prefix(job.job_id))
      expect(ttl).to be_within(10).of(BawWorkers::ActiveJob::Status::Persistence::TERMINAL_EXPIRE_IN)
    end
  end

  describe 'a failure to enqueue' do
    let(:job) {
      Fixtures::NeverQueuedJob.try_perform_later('never_queued')
    }

    it 'expects result to be false' do
      expect(job).to be_failure
    end

    it 'has returned the job object' do
      expect(job.failure).to be_an_instance_of(Fixtures::NeverQueuedJob)
    end

    it 'to have a job_id' do
      expect(job.failure.job_id).to eq('Fixtures::NeverQueuedJob:never_queued')
    end

    it 'has removes the status' do
      status = job.failure.refresh_status!
      expect(status).to be_nil
    end

    it 'has removes the status from the known statuses list' do
      expect(persistence.get_status_ids).to be_empty
    end

    it 'throws instead with perform_later!' do
      expect {
        Fixtures::NeverQueuedJob.perform_later!('never_queued')
      }.to raise_error(BawWorkers::ActiveJob::EnqueueError)
    end
  end

  describe 'retry', :slow do
    let(:job) { Fixtures::RetryableJob.perform_later!("will_retry#{Time.zone.now.strftime('%m%d%YT%H%M%S')}") }

    it 'merges messages for retries' do
      # dereference to kick it it off
      original_time = job.status.time

      # expect three jobs performed:
      # 1) attempt 1 / execution 0 --> failure
      # 2) attempt 2 / execution 1 --> failure
      # 3) attempt 3 / execution 2 --> success
      # - timeout based on jitter and back off: https://edgeapi.rubyonrails.org/classes/ActiveJob/Exceptions/ClassMethods.html#method-i-retry_on
      # - we've got a fixed period of 1s for our fixture
      # - if this test fails, check the scheduler container was running correctly!
      perform_jobs(count: 3, timeout: 10)

      job.refresh_status!
      job_refresh = ActiveJob::Base.deserialize(job.status.options.with_indifferent_access)

      aggregate_failures {
        expect(job_refresh.executions).to eq 2
        expect(job.status.options[:executions]).to eq 2
        expect(job.status.messages).to \
          match(
            a_collection_containing_exactly(
              'Attempt 1',
              'tick 1/3',
              /The job failed because of an error: BawWorkers::Jobs::IntentionalRetry at .*/,
              'Attempt 2',
              'tick 2/3',
              /The job failed because of an error: BawWorkers::Jobs::IntentionalRetry at .*/,
              'Attempt 3',
              'tick 3/3',
              a_string_matching(/Completed at/)
            )
          )
        expect(job.status.time).to be_within(0.001.seconds).of(original_time)
      }
    end
  end

  describe 'perform_now works' do
    # essentially no effect here since perform_now does not enqueue
    pause_all_jobs

    let(:job) { Fixtures::BasicJob.new('immediate') }

    it 'has the expected job_id' do
      expect(job.job_id).to eq 'Fixtures::BasicJob:immediate'
    end

    it 'backfills a status object' do
      job.perform_now
      expect(job.status).to be_an_instance_of(BawWorkers::ActiveJob::Status::StatusData)

      expect(job.status).to be_completed

      #job.refresh_status!
      # unlike other jobs, we have the instance of the job that
      # performed the work... so fetch from redis to see if it
      # really got updates
      remote_status = BawWorkers::ActiveJob::Status::Persistence.get(job.job_id)
      expect(remote_status).not_to be_nil
      expect(remote_status).to be_completed
      expect(remote_status.messages).to include(/Completed at/)
      expect(remote_status.messages).to include('previous status not found - was this job run with #perform_now')
    end
  end
end
