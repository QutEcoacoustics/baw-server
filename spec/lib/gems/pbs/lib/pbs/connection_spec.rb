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
      submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 2 && echo \'hello\'" | qsub -')
      expect(submit).to be_success

      submit_id = submit.value!.first.strip

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

    it 'can handle searching for a job that does not exist' do
      result = connection.fetch_status('9999')

      expect(result).to be_failure
      expect(result.failure).to match(/Unknown Job Id/)
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
        Server pbs

      OUTPUT
      allow(connection).to receive(:execute).and_return([0, stdout, nil])

      expect(connection.fetch_max_queued).to eq Success(nil)
    end

    it 'can fetch max queue size if the value is set to 0' do
      stdout = <<~OUTPUT
        Server pbs
          max_queued = [u:PBS_GENERIC=0]


      OUTPUT
      allow(connection).to receive(:execute).and_return([0, stdout, nil])

      expect(connection.fetch_max_queued).to eq Success(nil)
    end

    it 'can fetch max array size' do
      expect(connection.fetch_max_array_size).to eq Success(10_000)
    end

    it 'can fetch max array size if the value is not set' do
      stdout = <<~OUTPUT
        Server pbs

      OUTPUT
      allow(connection).to receive(:execute).and_return([0, stdout, nil])

      expect(connection.fetch_max_array_size).to eq Success(nil)
    end

    it 'can fetch max array size if the value is set to 0' do
      stdout = <<~OUTPUT
        Server pbs
          max_array_size = 0


      OUTPUT
      allow(connection).to receive(:execute).and_return([0, stdout, nil])

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
          job_name: 'test_job'
        )

        expect(result).to be_success
        connection.send(:remote_exist?, Settings.batch_analysis.root_data_path_mapping.cluster / 'test.sh')

        job_id = result.value!

        # @type [::PBS::Models::Job]
        job = connection.fetch_status(job_id).value!

        aggregate_failures do
          expect(job.job_name).to eq 'dev_test_job'
          expect(job.project).to eq BawApp.env

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
        stdout, = result.value!

        expect(stdout).to match(/waiting/)

        job = connection.fetch_status(job_id).value!

        expect(job).to be_finished
        expect(job.exit_status).to eq PBS::ExitStatus::CANCELLED_EXIT_STATUS

        output = working_directory.glob('*.log').first
        log = output.read

        expect(log).to include('LOG: TERM trap: job killed or cancelled')
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
