# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::Status do
  require 'support/shared_test_helpers'
  extend WebServerHelper::ExampleGroup
  include_context 'shared_test_helpers'

  create_audio_recordings_hierarchy

  pause_all_jobs

  let!(:saved_search) {
    Creation::Common.create_saved_search(writer_user, project,
      site_id: { eq: site.id })
  }
  let(:analysis_job) { create_analysis_job_direct }
  let(:queue_name) { Settings.actions.analysis.queue }

  let!(:script) {
    create(
      :script,
      creator: admin_user,
      executable_command: 'echo  "<{file_executable}>" audio2csv /source:"<{file_source}>" /config:"<{file_config}>" /tempdir:"<{dir_temp}>" /output:"<{dir_output}>"',
      executable_settings: 'staticsettings',
      analysis_action_params: {
        file_executable: './AnalysisPrograms/AnalysisPrograms.exe',
        copy_paths: [
          './programs/AnalysisPrograms/Logs/log.txt'
        ],
        sub_folders: []
      }
    )
  }

  def create_analysis_job_direct
    this_script = script
    puts "creating analysis job using script with id #{this_script.id} and settings '#{this_script.executable_settings}'"
    analysis_job = AnalysisJob.new
    analysis_job.script_id = this_script.id
    analysis_job.saved_search_id = saved_search.id
    analysis_job.name = "Analysis Job ##{Time.now}"
    analysis_job.custom_settings = this_script.executable_settings
    analysis_job.description = 'Description...'
    analysis_job.creator = writer_user

    analysis_job.save!

    analysis_job.prepare!

    analysis_job
  end

  def prepare_audio_file
    link_original_audio(
      target: Fixtures.audio_file_mono,

      uuid: audio_recording.uuid,
      datetime_with_offset: audio_recording.recorded_date,
      original_format: 'mp3'
    )
  end

  context 'with a web server' do
    expose_app_as_web_server

    it 'sets the website status to :completed if it just works' do
      # set up
      expect_queue_count(queue_name, 0)

      # prepare
      prepare_audio_file

      # enqueue
      analysis_job

      # run
      expect_queue_count(queue_name, 1)
      perform_jobs(count: 1)

      # assert
      analysis_job.reload
      expect(analysis_job).to be_completed
      expect(analysis_job.analysis_jobs_items).to all(be_successful)
    end

    it 'sets the website status to :timed_out if it times out' do
      # set up
      expect_queue_count(queue_name, 0)

      # override the timeout value
      allow(BawWorkers::Jobs::Analysis::Runner).to receive(:timeout_seconds).and_return(0.05)

      # set up
      expect_queue_count(queue_name, 0)

      # prepare
      prepare_audio_file

      # and insert a sleep into the command to run
      script.executable_command = 'sleep 5 && echo <{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>"'
      script.save!

      # enqueue
      analysis_job

      # run
      expect_queue_count(queue_name, 1)
      expect {
        perform_job_locally(queue_name)
      }.to raise_error(BawAudioTools::Exceptions::AudioToolTimedOutError, /time_out_sec=0.05/)

      # assert
      analysis_job.reload
      expect(analysis_job).to be_completed
      expect(analysis_job.analysis_jobs_items).to all(be_timed_out)
    end

    it 'sets the website status to :failed if the job fails' do
      # set up
      expect_queue_count(queue_name, 0)

      # prepare
      prepare_audio_file
      # and insert error output into the command to run
      script.executable_command = 'echo <{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>" >&2 && (exit 1)'
      script.save!

      # enqueue
      analysis_job

      # run
      expect_queue_count(queue_name, 1)
      perform_jobs(count: 1)

      # assert
      analysis_job.reload
      expect(analysis_job).to be_completed
      expect(analysis_job.analysis_jobs_items).to all(be_failed)
    end

    it 'sets the website status to :cancelled if the job was killed by the website' do
      # set up
      expect_queue_count(queue_name, 0)

      # prepare
      prepare_audio_file
      # and insert error output into the command to run
      script.executable_command = 'echo <{file_executable}> "analysis_type -source <{file_source}> -config <{file_config}> -output <{dir_output}> -tempdir <{dir_temp}>" >&2 && (exit 1)'
      script.save!

      # enqueue
      analysis_job
      analysis_job.transition_to_state!(:suspended)
      analysis_job.save!

      # run
      expect_queue_count(queue_name, 1)
      perform_jobs(count: 1)

      # assert
      analysis_job.reload
      expect(analysis_job).to be_suspended
      expect(analysis_job.analysis_jobs_items).to all(be_cancelled)
    end
  end

  context 'without a web server' do
    # tests a retry with exponential back-off, takes about 30 seconds
    it 'tries multiple times to set the website, and sends an email if it cant', :slow do
      # set up
      expect_queue_count(queue_name, 0)

      # enqueue
      analysis_job

      expect_queue_count(queue_name, 1)

      # prepare
      prepare_audio_file
      expect(BawWorkers::Config.api_communicator).to receive(:request_login).and_call_original.exactly(4).times

      time = Benchmark.realtime {
        expect {
          perform_job_locally(queue_name)
        }.to raise_error(BawWorkers::Exceptions::AnalysisEndpointError, /Could not log in./)
      }
      expect(time).to be_within(1.0).of(27 + 1.2)

      # new user + job start + error email
      expect(ActionMailer::Base.deliveries.count).to eq(3)
    end
  end
end
