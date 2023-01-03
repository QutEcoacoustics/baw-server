# frozen_string_literal: true

describe PBS::Connection do
  it 'can create an Connection' do
    PBS::Connection.new(Settings.batch_analysis)
  end

  it 'will throw without valid settings' do
    expect {
      PBS::Connection.new(nil)
    }.to raise_error(ArgumentError)
  end

  it 'will can connect with a password' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: 'password',
      key_file: nil
    ))
    connection = PBS::Connection.new(settings)
    expect(connection.test_connection).to be true
  end

  it 'will can connect with a private key' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: nil,
      key_file: './provision/analysis/client_key'
    ))
    connection = PBS::Connection.new(settings)
    expect(connection.test_connection).to be true
  end

  it 'will prioritize private key over password' do
    settings = Settings.batch_analysis.new(connection: Settings.batch_analysis.connection.new(
      password: 'obviously incorrect password',
      key_file: './provision/analysis/client_key'
    ))
    connection = PBS::Connection.new(settings)
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

      id_and_job = connection.fetch_status(submit_id)

      expect(id_and_job).to be_success
      id_and_job.value! => id, job
      expect(id).to eq submit_id
      expect(job).to be_running

      wait_for_pbs_job(submit_id)

      id_and_job = connection.fetch_status(submit_id)

      expect(id_and_job).to be_success
      expect(id_and_job.value!.second).to be_finished
    end

    it 'can fetch all job statuses' do
      5.times do
        submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 2 && echo \'hello\'" | qsub -')
        expect(submit).to be_success
      end

      result = connection.fetch_all_statuses

      expect(result).to be_success

      # @type [::PBS::Models::JobList]
      job_list = result.value!

      expect(job_list.jobs.count).to eq 5
    end

    it 'can fetch queue statuses' do
      5.times do
        submit = connection.send(:execute_safe, 'echo "/usr/bin/sleep 5 && echo \'hello\'" | qsub -')
        expect(submit).to be_success
      end

      result = connection.fetch_queue_status

      expect(result).to be_success

      # @type [::PBS::Models::QueueList]
      queue_list = result.value!

      expect(queue_list.queue.count).to eq 1

      # @type [::PBS::Models::Queue]
      workq = queue_list.queue['workq']
      expect(workq.total_jobs).to eq 5
    end

    it 'can fetch max queue size' do
      expect(connection.fetch_max_queued).to eq Success(5000)
    end

    it 'can fetch max array size' do
      expect(connection.fetch_max_array_size).to eq Success(10_000)
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

        pair = connection.fetch_status(job_id).value!
        # @type [::PBS::Models::Job]
        job = pair.second

        aggregate_failures do
          expect(job.job_name).to eq 'test_job'
          expect(job.project).to eq BawApp.env

          # the default queue for our test PBS cluster is `workq`
          expect(job.queue).to eq 'workq'

          expect(job.variable_list[PBS::Connection::ENV_PBS_O_WORKDIR]).to eq working_directory.to_s
        end

        job = wait_for_pbs_job(job_id)

        aggregate_failures do
          output = working_directory.glob('test_job.o*').first

          expect(output).to be_exist
          # 2022-10-20T03:08:28+00:00 LOG: Begin
          # 2022-10-20T03:08:28+00:00 LOG: vars: PBS_JOBNAME=test_job PBS_JOBID=1063.725ccdf1a5fb PBS_O_WORKDIR=/data/test/analysis_results/ar/audio_recording_id TMPDIR=/var/tmp/pbs.1064.725ccdf1a5fb
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
          expect(log).to match(%r{vars: PBS_JOBNAME=test_job PBS_JOBID=.* PBS_O_WORKDIR=/data/test/analysis_results/ar/audio_recording_id TMPDIR=/var/tmp/pbs\..*})
          expect(log).to include('NOOP start hook')
          expect(log).to include('NOOP finish hook')

          touch = working_directory / 'i_was_here'
          expect(touch).to be_exist

          expect(job.exit_status).to eq 0
        end
      end

      it 'will accept custom job hooks' do
        result = connection.submit_job(
          'echo "hello tests my pwd is $(pwd)" && touch i_was_here',
          working_directory,
          report_start_script: 'echo "Hello Clem"',
          report_finish_script: 'echo "Hello Cassian Andor"'
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        output = working_directory.glob("#{job.job_name}.o*").first
        log = output.read

        expect(log).to include('Hello Clem')
        expect(log).to include('Hello Cassian Andor')
      end

      it 'will run the error hooks on failure' do
        result = connection.submit_job(
          'cd i_do_not_exist',
          working_directory,
          report_error_script: 'echo "Congratulations. You\'re Being Rescued."'
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        expect(job.exit_status).to eq 1

        output = working_directory.glob("#{job.job_name}.o*").first
        log = output.read

        expect(log).to include('cd: i_do_not_exist: No such file or directory')
        expect(log).to include('Congratulations. You\'re Being Rescued.')
      end

      it 'will let us set variables' do
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
        job = wait_for_pbs_job(job_id)

        output = working_directory.glob("#{job.job_name}.o*").first
        log = output.read

        expect(log).to include('I find that answer vague and unconvincing.')
        expect(log).to include('We were on the verge of greatness.')
      end

      it 'will let us select resources' do
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
        # PBS downcases the units for some reason ughhhhh
        expect(job.resource_list.mem).to eq '256mb'
        expect(job.resource_list.walltime).to eq '00:01:00'
      end

      it 'will set the primary group by default' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory
        )

        expect(result).to be_success
        job_id = result.value!
        job = wait_for_pbs_job(job_id)

        expect(job.group_list).to eq Settings.batch_analysis.primary_group
      end

      it 'can submit a help job' do
        result = connection.submit_job(
          'echo "I’m capable of running my own diagnostics, thank you very much."',
          working_directory,
          {
            hold: true
          }
        )

        expect(result).to be_success
        job_id = result.value!

        status = connection.fetch_status(job_id)
        expect(status).to be_held

        release_result = connection.release_job(job_id)
        expect(release_result).to be_success

        job = wait_for_pbs_job(job_id)

        expect(job).to be_success
        expect(job.value!.second).to be_finished
      end
    end
  end
end
