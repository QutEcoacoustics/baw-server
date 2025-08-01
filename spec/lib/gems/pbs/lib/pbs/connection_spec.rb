# frozen_string_literal: true

describe PBS::Connection do
  it 'can create an Connection' do
    PBS::Connection.new(Settings.batch_analysis, 'tag')
  end

  it 'omits sensitive detail in inspect' do
    connection = PBS::Connection.new(Settings.batch_analysis, 'tag')
    expect(connection.inspect).not_to include('password')
    expect(connection.inspect).not_to include('key_file')
  end

  it 'throws without valid settings' do
    expect {
      PBS::Connection.new(nil)
    }.to raise_error(ArgumentError)
  end

  it 'throws without valid settings (tag)' do
    expect {
      PBS::Connection.new(Settings.batch_analysis, nil)
    }.to raise_error(ArgumentError)
  end

  it 'can connect with a password' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: 'password',
      key_file: nil
    ))
    connection = PBS::Connection.new(settings, 'tag')
    expect(connection.test_connection).to be true
  end

  it 'can connect with a private key' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: nil,
      key_file: './provision/analysis/client_key'
    ))
    connection = PBS::Connection.new(settings, 'tag')
    expect(connection.test_connection).to be true
  end

  it 'prioritizes private key over password' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: 'obviously incorrect password',
      key_file: './provision/analysis/client_key'
    ))
    connection = PBS::Connection.new(settings, 'tag')
    expect(connection.test_connection).to be true
  end

  describe 'bin_path' do
    it 'does not append a path prefix if bin_path is nil' do
      settings = Settings.batch_analysis.new(pbs: Settings.batch_analysis.pbs.new(bin_path: nil))
      connection = PBS::Connection.new(settings, 'tag')

      allow(connection).to receive(:execute_pbs_command).and_return(Dry::Monads::Result.pure(
        PBS::Result.new(0, '', '', nil)
      ))
      connection.fetch_queued_count
      expect(connection).to have_received(:execute_pbs_command).with('qselect -s Q -u pbsuser | wc -l')
    end

    it 'appends a path prefix if bin_path is set' do
      settings = Settings.batch_analysis.new(pbs: Settings.batch_analysis.pbs.new(bin_path: '/opt/pbs/bin'))
      connection = PBS::Connection.new(settings, 'tag')

      allow(connection).to receive(:execute_pbs_command).and_return(Dry::Monads::Result.pure(PBS::Result.new(0, '', '',
        nil)))
      connection.fetch_queued_count
      expect(connection).to have_received(:execute_pbs_command).with('/opt/pbs/bin/qselect -s Q -u pbsuser | wc -l')
    end
  end

  describe 'commands' do
    include Dry::Monads[:result]

    include_context 'shared_test_helpers'
    include PBSHelpers::Example

    # @!attribute [r] connection
    #   @return [PBS::Connection]

    before do
      clear_analysis_cache
    end

    it 'can test a connection' do
      expect(connection.test_connection).to be true
    end

    it 'can fetch a job status' do
      submit = connection.send(:execute_pbs_command, 'echo "/usr/bin/sleep 2 && echo \'hello\'" | qsub -')
      expect(submit).to be_success

      submit_id = submit.value!.stdout.strip

      result = connection.fetch_status(submit_id)

      expect(result).to be_success
      result.value! => job
      expect(job.job_id).to eq submit_id
      expect(job).to be_running

      wait_for_pbs_job(submit_id)

      result = connection.fetch_status(submit_id)

      expect(result).to be_success
      expect(result.value!).to be_finished
    end

    # https://github.com/QutEcoacoustics/baw-server/issues/729
    it 'can handle fetching a job status which does not tell us about all the resources used' do
      submit = connection.send(:execute_pbs_command, 'echo "/usr/bin/sleep 2 && echo \'hello\'" | qsub -')
      expect(submit).to be_success

      submit_id = submit.value!.stdout.strip
      wait_for_pbs_job(submit_id)

      allow(connection).to receive(:execute_pbs_command).and_wrap_original do |m, *args, **keyword_args|
        original_result = m.call(*args, **keyword_args)

        next original_result unless args.first.include?('qstat')

        expect(original_result).to be_success
        command_result = original_result.value!

        # in production, we found instances where ncpus, vmem, and walltime were not reported by qstat under some conditions
        stdout = command_result.stdout.gsub(
          /"resources_used":{[^}]+}/,
          '"resources_used":{"cpupercent":0,"cput":"00:00:00","mem":"0b"}'
        )

        Success(command_result.with(stdout:))
      end
      result = connection.fetch_status(submit_id)

      # @type [::PBS::Models::Job]
      job = result.value!

      expect(job.resources_used.ncpus).to be_nil
      expect(job.resources_used.vmem).to be_nil
      expect(job.resources_used.walltime).to be_nil
      expect(job.resources_used.cpupercent).to eq 0
    end

    it 'can handle searching for a job that does not exist' do
      result = connection.fetch_status('9999')

      expect(result).to be_failure
      expect(result.failure).to be_a(PBS::Errors::JobNotFoundError)
    end

    # https://github.com/QutEcoacoustics/baw-server/issues/776
    it 'can handle cluster connection errors' do
      stderr = <<~STDERR
        Connection refused
        qstat: cannot connect to server 6cfab3a0b8ac (errno=15010)
      STDERR
      stdout = <<~STDOUT
        {
          "timestamp":1750053827,
          "pbs_version":"22.05.11",
          "pbs_server":"6cfab3a0b8ac"
        }
      STDOUT
      allow(connection).to receive(:execute_safe).and_return(
        Failure(PBS::Result.new(255, stdout, stderr, nil))
      )

      result = connection.fetch_status('9999')

      expect(result).to be_failure
      expect(result.failure).to be_a(PBS::Errors::ConnectionRefusedError)
      expect(result.failure).to be_a(PBS::Errors::TransientError)
    end

    # https://github.com/QutEcoacoustics/baw-server/issues/789
    it 'can handle no route to host errors' do
      stdout = <<~STDOUT
        {
          "timestamp":1751498039,
          "pbs_version":"2025.2.0.20250218043111",
          "pbs_server":"aqua"
        }
      STDOUT
      stderr = <<~STDERR
        No route to host
        qstat: cannot connect to server aqua (errno=15010)
      STDERR
      allow(connection).to receive(:execute_safe).and_return(
        Failure(PBS::Result.new(255, stdout, stderr, nil))
      )

      result = connection.fetch_status('9999')

      expect(result).to be_failure
      expect(result.failure).to be_a(PBS::Errors::NoRouteToHostError)
      expect(result.failure).to be_a(PBS::Errors::TransientError)
    end

    stepwise 'when fetching all statuses' do
      step 'fetch all statuses works with an empty queue' do
        result = connection.fetch_all_statuses

        expect(result).to be_success

        # @type [::PBS::Models::JobList]
        job_list = result.value!

        expect(job_list.jobs).to be_empty
      end

      step 'generate some jobs' do
        10.times do
          submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 2 && echo \'hello\'" | qsub -')
          expect(submit).to be_success
        end
      end

      step 'can fetch all job statuses (default limit 25)' do
        result = connection.fetch_all_statuses

        expect(result).to be_success

        # @type [::PBS::Models::JobList]
        job_list = result.value!

        expect(job_list.jobs.count).to eq 10
      end

      step 'can fetch all job statuses (without default limit)' do
        result = connection.fetch_all_statuses(take: nil)

        expect(result).to be_success

        # @type [::PBS::Models::JobList]
        job_list = result.value!

        expect(job_list.jobs.count).to eq 10
      end

      step 'can fetch all job statuses (with limit)' do
        result = connection.fetch_all_statuses(take: 2)

        expect(result).to be_success

        # @type [::PBS::Models::JobList]
        job_list = result.value!

        expect(job_list.jobs.count).to eq 2
      end

      step 'can fetch all job statuses (with limit and offset)' do
        all = connection.fetch_all_statuses(take: nil)
        expected_ids = all.value!.jobs.values[8..10].map(&:job_id)

        result = connection.fetch_all_statuses(take: 10, skip: 8)

        expect(result).to be_success

        # @type [::PBS::Models::JobList]
        job_list = result.value!

        expect(job_list.jobs.count).to eq 2
        expect(job_list.jobs.values.map(&:job_id)).to eq expected_ids
      end
    end

    it 'can fetch queue statuses' do
      5.times do
        submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 5 && echo \'hello\'" | qsub -')
        expect(submit).to be_success
      end

      result = connection.fetch_all_queue_statuses

      expect(result).to be_success

      # @type [::PBS::Models::QueueList]
      queue_list = result.value!

      expect(queue_list.queue.count).to eq 1

      # @type [::PBS::Models::Queue]
      workq = queue_list.queue['workq']
      expect(workq.total_jobs).to eq 5
    end

    it 'can fetch enqueued and running job counts' do
      expect(connection.fetch_enqueued_count).to eq Success(0)
      expect(connection.fetch_queued_count).to eq Success(0)
      expect(connection.fetch_running_count).to eq Success(0)

      10.times do
        submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 30 && echo \'hello\'" | qsub -')
        expect(submit).to be_success
      end

      # we have a max limit of 5 running jobs

      expect(connection.fetch_running_count).to eq Success(5)
      expect(connection.fetch_queued_count).to eq Success(5)
      expect(connection.fetch_enqueued_count).to eq Success(10)
    end

    it 'can fetch max queue size' do
      expect(connection.fetch_max_queued).to eq Success(10)
    end

    it 'can fetch max queue size if the value is not set' do
      stdout = <<~OUTPUT
        Server aqua
            max_queued = [u:user01=0]
            max_queued = [u:user02=0]
            max_queued = [u:user03=0]
            max_queued = [u:user04=0]
            max_queued = [u:user05=0]
            max_queued = [u:user06=0]
            max_queued = [u:user07=0]
            max_queued = [u:user08=0]
            max_queued = [u:user09=0]
            max_queued = [u:user10=0]
            max_queued = [u:user11=0]
            max_queued = [u:user12=0]
            max_queued = [u:user13=0]
            max_queued = [u:user14=0]
            max_queued = [u:user15=0]
            max_queued = [u:user16=0]
            max_queued = [u:user17=0]
            max_queued = [u:user18=0]

      OUTPUT
      allow(connection).to receive(:execute).and_return(PBS::Result[0, stdout, nil, nil])

      expect(connection.fetch_max_queued).to eq Success(nil)
    end

    describe 'limit parsing tests' do
      let(:stdout) {
        <<~OUTPUT
          Server pbs
              max_queued = [u:PBS_GENERIC=20]
              max_queued = [o:PBS_ALL=50]
              max_queued = [g:PBS_GENERIC=40]
              max_queued = [p:PBS_GENERIC=30]
              max_queued = [u:user123=5]
              max_queued = [u:"user with spaces"=15]
              max_queued = [g:groupname=10]
              max_queued = [g:'group with spaces'=12]
              max_queued = [p:projectname=17]
              max_queued = [u:banned_user=0]

        OUTPUT
      }

      def choose_lowest_limit(limits)
        limits.map(&:value).compact.min
      end

      [
        ['pbsuser', 'pbsgroup', 'pbsproject', 'generic user', 20],
        ['user123', 'pbsgroup', 'pbsproject', 'user123', 5],
        ['user with spaces', 'pbsgroup', 'pbsproject', 'user with spaces', 15],
        ['pbsuser', 'groupname', 'pbsproject', 'group name', 10],
        ['afadfads', 'afdfa', 'projectname', 'project name', 17],
        ['banned_user', 'pbsgroup', 'projectname', 'banned user', 0],
        [nil, nil, nil, 'generic user (no user matching)', 20],
        ['pbsuser', 'group with spaces', 'pbsproject', 'group with spaces', 12]
      ].each do |user, group, project, description, expected_max|
        it "can parse max_queued when limited by #{description}" do
          result = connection.send(:parse_qmgr_limit_list, stdout, 'max_queued', user, group, project)

          expect(choose_lowest_limit(result)).to eq expected_max
        end
      end

      it 'returns nil if no conditions match' do
        output = <<~OUTPUT
          Server pbs
              max_queued = [u:unknown_user=0]
        OUTPUT

        result = connection.send(:parse_qmgr_limit_list, output, 'max_queued', 'pbsuser', 'pbsgroup', 'pbsproject')

        expect(choose_lowest_limit(result)).to eq nil
      end

      it 'can PBS_ALL if it is lower than user' do
        output = <<~OUTPUT
          Server pbs
              max_queued = [o:PBS_ALL=50]
              max_queued = [u:unknown_user=100]
        OUTPUT

        result = connection.send(:parse_qmgr_limit_list, output, 'max_queued', 'unknown_user', 'pbsgroup', 'pbsproject')

        expect(choose_lowest_limit(result)).to eq 50
      end
    end

    it 'can fetch max queue size if the value is set to 0' do
      stdout = <<~OUTPUT
        Server pbs
          max_queued = [u:PBS_GENERIC=0]


      OUTPUT
      allow(connection).to receive(:execute).and_return(PBS::Result[0, stdout, nil, nil])

      expect(connection.fetch_max_queued).to eq Success(0)
    end

    it 'can fetch max queue size with more complicated rules' do
      stdout = <<~OUTPUT

      OUTPUT
      allow(connection).to receive(:execute).and_return(PBS::Result[0, stdout, nil, nil])
    end

    it 'can fetch max array size' do
      expect(connection.fetch_max_array_size).to eq Success(nil)
    end

    it 'can fetch max array size if the value is not set' do
      stdout = <<~OUTPUT
        Server pbs

      OUTPUT
      allow(connection).to receive(:execute).and_return(PBS::Result[0, stdout, nil, nil])

      expect(connection.fetch_max_array_size).to eq Success(nil)
    end

    it 'can fetch max array size if the value is set to 0' do
      stdout = <<~OUTPUT
        Server pbs
          max_array_size = 0


      OUTPUT
      allow(connection).to receive(:execute).and_return(PBS::Result[0, stdout, nil, nil])

      expect(connection.fetch_max_array_size).to eq Success(nil)
    end

    context 'when submitting jobs' do
      let(:working_directory) {
        Pathname(Settings.paths.cached_analysis_jobs.first) / 'ar' / 'audio_recording_id'
      }

      it 'can submit a job' do
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)" && touch i_was_here',
          working_directory,
          job_name: 'test_job',
          project_suffix: "she's alive!"
        )

        expect(result).to be_success
        connection.send(:remote_exist?, Settings.batch_analysis.root_data_path_mapping.cluster / 'test.sh')

        job_id = result.value!

        # @type [::PBS::Models::Job]
        job = connection.fetch_status(job_id).value!

        aggregate_failures do
          expect(job.job_name).to eq 'dev_test_job'
          expect(job.project).to eq("#{Settings.organisation_names.site_short_name}_she_s_alive")

          # the default queue for our test PBS cluster is `workq`
          expect(job.queue).to eq 'workq'

          expect(
            job.variable_list[PBS::Connection::ENV_PBS_O_WORKDIR]
          ).to eq working_directory.to_s
        end

        job = wait_for_pbs_job(job_id)

        aggregate_failures do
          output = working_directory.glob('test_job.log').first

          expect(output).to be_exist
          # 2022-10-20T03:08:28+00:00 LOG: Begin
          # 2022-10-20T03:08:28+00:00 LOG: vars: PBS_JOBNAME=dev_test_job PBS_JOBID=1063.725ccdf1a5fb PBS_O_WORKDIR=/data/test/analysis_results/ar/audio_recording_id TMPDIR=/var/tmp/pbs.1064.725ccdf1a5fb
          # 2022-10-20T03:08:28+00:00 LOG: Reporting start
          # 2022-10-20T03:08:28+00:00 LOG: NOOP start hook
          # 2022-10-20T03:08:28+00:00 LOG: Begin custom portion
          # hello tests my pwd is /data/test/analysis_results/ar/audio_recording_id
          # 2022-10-20T03:08:28+00:00 LOG: Finish custom portion
          # 2022-10-20T03:08:28+00:00 LOG: Reporting finish
          # 2022-10-20T03:08:28+00:00 LOG: NOOP finish hook
          # 2022-10-20T03:08:28+00:00 LOG: Success
          log = output.read
          expect(log).to include "hello tests my pwd is #{working_directory}\n"
          expect(log).to match(%r{vars: PBS_JOBNAME=dev_test_job PBS_JOBID=.* PBS_O_WORKDIR=/data/test/analysis_results/ar/audio_recording_id TMPDIR=/var/tmp/pbs\..*})
          expect(log).to include('NOOP start hook')
          expect(log).to include('NOOP finish hook')

          touch = working_directory / 'i_was_here'
          expect(touch).to be_exist

          expect(job.exit_status).to eq 0
        end
      end

      it 'can check if a job exists' do
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)"',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!

        expect(connection.job_exists?(job_id)).to be_success.and(have_attributes(value!: true))
        expect(connection.job_exists?('9999')).to be_success.and(have_attributes(value!: false))
      end

      it 'can cancel a job (and wait for it)' do
        result = connection.submit_job(
          'sleep 30',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!

        # @type [::PBS::Models::Job]
        job = connection.fetch_status(job_id).value!

        expect(job).to be_running

        result = connection.cancel_job(job_id, wait: true)
        stdout = result.value!.stdout

        expect(stdout).to match(/waiting/)

        job = connection.fetch_status(job_id).value!

        expect(job).to be_finished
        expect(job.exit_status).to eq PBS::ExitStatus::CANCELLED_EXIT_STATUS

        output = working_directory.glob('*.log').first
        log = output.read

        expect(log).to include('LOG: TERM trap: job killed or cancelled')
      end

      it 'is graceful when canceling a job that has already finished' do
        # arrange
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)"',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!

        job = wait_for_pbs_job(job_id)
        expect(job).to be_finished

        # act
        result = connection.cancel_job(job_id, wait: true)

        # assert
        expect(result).to be_success
        result.value! => { stdout:, stderr: }
        expect(stderr).to match(/Job has finished/)
        expect(stdout).not_to match(/waiting/)
      end

      # https://github.com/QutEcoacoustics/baw-server/issues/776
      it 'uses an exception failure when connection is refused when canceling a job' do
        allow(connection).to receive(:execute_safe).and_return(
          Failure(PBS::Result.new(255, '', 'Connection refused', nil))
        )
        result = connection.cancel_job('9999', wait: true, force: true)

        expect(result).to be_failure
        expect(result.failure).to be_a(PBS::Errors::ConnectionRefusedError)
      end

      it 'is graceful when canceling a job that is not in the job history' do
        # arrange
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)"',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!

        job = wait_for_pbs_job(job_id)
        expect(job).to be_finished

        # we're simulating a completed job being cleared from history
        result = connection.cancel_job(job_id, wait: true, force: true, completed: true)
        expect(result).to be_success

        # act - now we try to cancel the job again
        result = connection.cancel_job(job_id, wait: true)

        # assert
        expect(result).to be_success

        result.value! => { stdout:, stderr: }
        expect(stderr).to match(/Unknown Job Id/)
        expect(stdout).not_to match(/waiting/)
      end

      # https://github.com/QutEcoacoustics/baw-server/issues/765
      it 'uses an exception failure when canceling a job that is in the process of finishing' do
        # arrange
        result = connection.submit_job(
          # this is a very poorly behaved job. The idea is a lot of stdout will
          # keep the job in the exiting state for a while
          'cat /dev/random',
          working_directory
        )
        job_id = result.value!

        sleep 1

        status_result = connection.fetch_status(job_id).value!
        raise 'not running' unless status_result.running?

        # we're trying to simulate a race condition where the job is cleaned up
        # while exiting. I can't work out how to extend the exiting state to test
        # this reliably, so we're just going to spam cancel requests and hope one
        # happens while the job is exiting
        cancel_result = nil
        100.times.map do
          result = connection.cancel_job(job_id, wait: false)
          if result.failure?
            cancel_result = result
            break
          end
        end
        status_result = connection.fetch_status(job_id).value!

        expect(cancel_result).to be_failure
        expect(cancel_result.failure).to be_a(PBS::Errors::InvalidStateError)
        expect(cancel_result.failure.message).to match(/Request invalid for state of job/)
        expect(cancel_result.failure.message).to match(PBS::Connection::QDEL_INVALID_STATE_STATUS.to_s)
        expect(status_result).to be_exiting
      end

      it 'can batch cancel jobs based on project_suffix', :slow do
        # arrange
        job_ids = []
        5.times do
          result = connection.submit_job(
            'sleep 30',
            working_directory,
            project_suffix: 'test'
          )

          expect(result).to be_success
          job_ids << result.value!
        end

        # test correct selection
        other_job = connection.submit_job(
          'sleep 30',
          working_directory,
          project_suffix: 'other'
        ).value!

        # pick a job to complete - to test graceful handling
        job = wait_for_pbs_job(job_ids[1])
        expect(job).to be_finished

        # pick a job to cancel - to test graceful handling
        connection.cancel_job(job_ids[2])

        # pick a job to delete history for - to test graceful handling
        wait_for_pbs_job(job_ids[3])
        connection.cancel_job(job_ids[3], wait: true, force: true, completed: true)
        expect(connection.job_exists?(job_ids[3])).to be_success.and(have_attributes(value!: false))

        # act
        result = connection.cancel_jobs_by_project!('test')

        # assert
        expect(result).to be_success
        job_ids.each do |job_id|
          expect(connection.job_exists?(job_id)).to be_success.and(have_attributes(value!: false))
        end

        expect(connection.job_exists?(other_job)).to be_success.and(have_attributes(value!: true))
      end

      it 'works cancelling no jobs based on project_suffix', :slow do
        expect(connection.cancel_jobs_by_project!('test')).to be_success
      end

      it 'accepts custom job hooks' do
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)" && touch i_was_here',
          working_directory,
          report_start_script: 'echo "Hello Clem"',
          report_finish_script: 'echo "Hello Cassian Andor"'
        )

        expect(result).to be_success
        job_id = result.value!
        wait_for_pbs_job(job_id)

        output = working_directory.glob('*.log').first
        log = output.read

        expect(log).to include('Hello Clem')
        expect(log).to include('Hello Cassian Andor')
      end

      context 'report_after_script hooks run' do
        include PBSHelpers

        submit_pbs_jobs_as_held

        def run(script, resources: {})
          result = connection.submit_job(
            script,
            working_directory,
            resources:,
            report_error_script:
            <<~SHELL
              log "Congratulations. You're Being Rescued."
            SHELL
          )

          expect(result).to be_success

          expect_enqueued_or_held_pbs_jobs(1)

          job_id = result.value!

          # the status should report a dependent job
          # @type [::PBS::Models::Job]
          connection.fetch_status(job_id).value!

          release_all_held_pbs_jobs

          yield job_id if block_given?

          wait_for_pbs_job(job_id)
        end

        def read_log
          output = working_directory.glob('*.log').first
          log = output.read

          expect(log).to include('LOG: Begin')

          log
        end

        it 'handles success' do
          main = run('echo "hello tests my pwd is $(pwd)"')

          expect(main.exit_status).to eq 0

          log = read_log
          expect(log).to include('Success')
          expect(log).not_to include('LOG: Congratulations. You\'re Being Rescued.')
        end

        it 'handles script failure' do
          main = run('cd i_do_not_exist')

          expect(main.exit_status).to eq 1

          log = read_log
          expect(log).not_to include('Success')

          expect(log).to include('LOG: ERR trap:1: reporting error from')

          # test error function only called once
          expect(log.scan('LOG: Congratulations. You\'re Being Rescued.').size).to eq 1
        end

        it 'handles cancellation' do
          main = run('sleep 30') { |main_id|
            # wait for the job to start
            sleep 1

            # cancel the job
            connection.cancel_job(main_id)

            # wait for the job to be cancelled
            sleep 1
          }

          expect(main.exit_status).to eq PBS::ExitStatus::CANCELLED_EXIT_STATUS

          log = read_log
          expect(log).not_to include('Success')
          expect(log).to include('LOG: ERR trap:143: reporting error from')
          expect(log).to include('LOG: TERM trap: job killed or cancelled')

          # test error function only called once
          expect(log.scan('LOG: Congratulations. You\'re Being Rescued.').size).to eq 1
        end

        it 'handles being killed because of resource limits' do
          main = run('sleep 30', resources: {
            walltime: 1
          })

          expect(main.exit_status).to eq PBS::ExitStatus::JOB_EXEC_KILL_WALLTIME

          log = read_log
          expect(log).not_to include('Success')
          expect(log).to include('PBS: job killed: walltime 10 exceeded limit 1')
          expect(log).to include('LOG: TERM trap: job killed or cancelled')
          expect(log).to include('LOG: ERR trap:143: reporting error from')

          # test error function only called once
          expect(log.scan('LOG: Congratulations. You\'re Being Rescued.').size).to eq 1
        end
      end

      context 'with preludes' do
        it 'emits nothing if it is not set' do
          settings = Settings.batch_analysis.new(pbs: Settings.batch_analysis.pbs.new(prelude_script: nil))
          connection = PBS::Connection.new(settings, 'tag')

          result = connection.submit_job(
            'echo "What is my purpose?"',
            working_directory,
            job_name: 'empty_prelude'
          )

          expect(result).to be_success

          # don't need to run the script just want to see it templated
          script = working_directory / 'empty_prelude'
          expect(script).to be_exist
          expect(script.read).to include <<~BASH
            # prelude
            # end prelude
          BASH
        end

        it 'emits the prelude if it is set' do
          settings = Settings.batch_analysis.new(pbs: Settings.batch_analysis.pbs.new(
            prelude_script: 'echo "You serve butter 😑"'
          ))
          connection = PBS::Connection.new(settings, 'tag')

          result = connection.submit_job(
            'echo "What is my purpose?"',
            working_directory,
            job_name: 'test_prelude'
          )

          expect(result).to be_success

          script = working_directory / 'test_prelude'
          expect(script).to be_exist
          expect(script.read).to include <<~BASH
            # prelude
            echo "You serve butter 😑"
            # end prelude
          BASH

          wait_for_pbs_job(result.value!)
          output = working_directory.glob('test_prelude.log').first
          log = output.read
          expect(log).to include('You serve butter 😑')
          expect(log).to include('What is my purpose?')
        end
      end

      it 'lets us set environment variables' do
        script = <<~BASH
          echo "$K2SO"
          echo "$Krennic"
        BASH
        result = connection.submit_job(
          script,
          working_directory,
          env: {
            K2SO: 'I find that answer vague and unconvincing.',
            Krennic: 'We were on the verge of greatness.'
          }
        )

        expect(result).to be_success
        job_id = result.value!
        wait_for_pbs_job(job_id)

        output = working_directory.glob('*.log').first
        log = output.read

        expect(log).to include('I find that answer vague and unconvincing.')
        expect(log).to include('We were on the verge of greatness.')
      end

      it 'lets us select resources' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory,
          resources: {
            ncpus: 1,
            mem: '256MB',
            walltime: 60
          }
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        expect(job.resource_list.ncpus).to eq 1

        # we normalize PBS' units to bytes and seconds
        expect(job.resource_list.mem).to eq 268_435_456
        expect(job.resource_list.walltime).to eq 60
      end

      it 'sets the primary group by default' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        expect(job.group_list).to eq Settings.batch_analysis.pbs.primary_group
      end

      it 'sets a reader/group umask by default' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        expect(job.submit_arguments).to match(/-W [\w=,]*umask=0002/)
      end

      it 'can submit a held job' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory,
          hold: true
        )

        expect(result).to be_success
        job_id = result.value!

        status = connection.fetch_status(job_id).value!
        expect(status.job_id).to eq(job_id)
        expect(status).to be_held

        release_result = connection.release_job(job_id)
        expect(release_result).to be_success

        job = wait_for_pbs_job(job_id)

        expect(job).to be_finished
      end

      it 'has a hidden job option' do
        result = connection.submit_job(
          'echo "We were on the verge of greatness."',
          working_directory,
          hidden: true,
          job_name: 'test_job'
        )

        expect(result).to be_success
        job_id = result.value!

        status = connection.fetch_status(job_id).value!
        expect(status.job_name).to eq 'dev_test_job'
        expected_output = working_directory / '.test_job.log'
        # pbs records hostname in front of the path
        expect(status.output_path).to match(/^\w+:#{expected_output}$/)

        release_result = connection.release_job(job_id)
        expect(release_result).to be_success

        job = wait_for_pbs_job(job_id)

        expect(job).to be_finished

        expect(working_directory / '.test_job').to be_exist
        expect(working_directory / '.test_job.log').to be_exist
      end

      it 'correctly maps the working directory to a remote directory' do
        # the data path mapping is identical in the this test environment.
        # To test the transform is actually done we set the path to an invalid value
        # and don't worry about running it.
        allow(Settings.batch_analysis.root_data_path_mapping)
          .to receive(:cluster).and_return('/data/test/some_path_that_should_not_exist')

        connection = PBS::Connection.new(Settings.batch_analysis, 'tag')
        result = connection.submit_job(
          'echo "We were on the verge of greatness."',
          working_directory
        )

        expect(result).to be_success
        job = connection.fetch_status(result.value!).value!

        expect(job.submit_arguments).to include('/data/test/some_path_that_should_not_exist')
        expect(job.error_path).to include('/data/test/some_path_that_should_not_exist')
        expect(job.output_path).to include('/data/test/some_path_that_should_not_exist')
      end
    end
  end
end
