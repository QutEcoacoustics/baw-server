# frozen_string_literal: true

require 'support/resque_helpers'
require 'rspec/mocks'

#
# Integration testing of AnalysisJobsController controller.
# API level tests should be put in acceptance/analysis_jobs_spec.rb
#

describe 'Analysis Jobs' do
  extend WebServerHelper::ExampleGroup
  include_context 'shared_test_helpers'
  create_audio_recordings_hierarchy

  # https://github.com/aasm/aasm#testing

  # create another 5 recordings
  let!(:other_recordings) {
    [
      Creation::Common.create_audio_recording(writer_user, writer_user, site),
      Creation::Common.create_audio_recording(writer_user, writer_user, site),
      Creation::Common.create_audio_recording(writer_user, writer_user, site),
      Creation::Common.create_audio_recording(writer_user, writer_user, site),
      Creation::Common.create_audio_recording(writer_user, writer_user, site)
    ]
  }

  let!(:saved_search) {
    Creation::Common.create_saved_search(
      writer_user, project,
      site_id: { eq: site.id }
    )
  }

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

  let(:queue_name) { Settings.actions.analysis.queue }
  let(:analysis_job_url) { '/analysis_jobs' }

  before do
    (other_recordings + [audio_recording]).each do |r|
      link_original_audio(
        target: Fixtures.audio_file_mono,
        uuid: r.uuid,
        datetime_with_offset: r.recorded_date,
        original_format: r.media_type
      )
    end
  end

  after(:all) do
    clear_original_audio
  end

  after do |example|
    if example.exception
      require 'json'

      job_ids = AnalysisJob.all.join(', ')
      job_items = AnalysisJobsItem.all.join('\n\t- ')

      puts <<~DEBUG
        Queue name: #{queue_name}
        Queue count: #{Resque.size(queue_name)}
        Failure count: #{Resque::Failure.count}
        All analysis job ids: #{job_ids}
        All analysis job items:\n#{job_items}
      DEBUG
    end
  end

  def job_items_count(status = nil)
    predicates = { analysis_job_id: analysis_job.id }
    predicates[:status] = status if status
    AnalysisJobsItem.where(predicates).count
  end

  def create_analysis_job
    this_script = script
    logger.info("creating analysis job using script with id #{this_script.id} and settings '#{this_script.executable_settings}'")
    body = {
      analysis_job: {
        script_id: this_script.id,
        saved_search_id: saved_search.id,
        name: "Analysis Job ##{Time.now}",
        custom_settings: this_script.executable_settings,
        description: 'Description...'
      }
    }

    post analysis_job_url, params: body, **api_with_body_headers(writer_token)

    raise "Failed to create test AnalysisJob, status: #{response.status}" if response.status != 201

    body = JSON.parse(response.body)
    AnalysisJob.find(body['data']['id'])
  end

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

    analysis_job
  end

  def update_analysis_job(analysis_job_id, overall_status)
    update_route = "/analysis_jobs/#{analysis_job_id}"

    put update_route, params: {
      analysis_job: {
        overall_status:
      }
    }, **api_with_body_headers(writer_token)

    raise "Failed to update AnalysisJob, status: #{response.status}" if response.status != 200
  end

  def destroy_analysis_job(analysis_job_id)
    destroy_route = "/analysis_jobs/#{analysis_job_id}"

    delete destroy_route, params: {}, **api_with_body_headers(writer_token)

    [response.status, response]
  end

  def test_stats(analysis_job, expected = {})
    opts = {
      overall_count: 0,
      overall_duration_seconds: 0,
      overall_data_length_bytes: 0,
      overall_progress: {
        queued: 0,
        working: 0,
        successful: 0,
        failed: 0,
        total: 0,
        cancelled: 0,
        cancelling: 0,
        new: 0,
        timed_out: 0
      }
    }

    expected = opts.deep_merge(expected)

    expected.each do |key, value|
      value = value.stringify_keys if value.is_a?(Hash)

      actual = analysis_job[key]
      expect(actual).to eq(value), "expected #{actual} for key #{key}, got #{value}"
    end
  end

  def test_stats_for(analysis_job, expected, n)
    opts = {
      overall_count: n,
      overall_duration_seconds: (n * 60_000),
      overall_data_length_bytes: (n * 3800)

    }

    expected = opts.deep_merge(expected)
    test_stats(analysis_job, expected)
  end

  def get_analysis_job_item(analysis_job_id, audio_recording_id)
    route = "/analysis_jobs/#{analysis_job_id}/audio_recordings/#{audio_recording_id}"

    get route, params: {}, headers: api_request_headers(writer_token)

    raise "Failed to get AnalysisJobItem, status: #{response.status}" if response.status != 200

    JSON.parse(response.body)
  end

  def update_analysis_job_item(analysis_job_id, audio_recording_id, status)
    update_route = "/analysis_jobs/#{analysis_job_id}/audio_recordings/#{audio_recording_id}"

    # only the harvester user can update job items!
    put update_route, params: {
      analysis_jobs_item: {
        status:
      }
    }, **api_with_body_headers(harvester_token)

    if response.status != 200
      raise "Failed to update AnalysisJobItem, status: #{response.status} #{response.message}\n#{response.body}"
    end
  end

  # attr_writer :job_perform_failure

  # def perform_jobs(count: 1)
  #   @job_perform_failure = nil

  #   # execute the next available job
  #   FakeAnalysisJob.test_instance = self
  #   ResqueHelpers::Emulate.resque_worker(@queue_name, true, false, 'FakeAnalysisJob')

  #   if @job_perform_failure && @job_perform_failure[0].message != 'Fake analysis job failing on purpose'

  #     message = @job_perform_failure if @job_perform_failure.is_a? String
  #     message = @job_perform_failure.join("\n") if @job_perform_failure.is_a? Array
  #     if @job_perform_failure.is_a? Exception
  #       message = @job_perform_failure.full_message
  #       message += @job_perform_failure.backtrace.join('\n')
  #     end

  #     raise "job perform failed: #{message}"
  #   end
  # end

  pause_all_jobs

  describe 'Creating an analysis job' do
    describe 'status: "new"' do
      let(:analysis_job) { create_analysis_job }

      before do
        # don't allow automatic transition to :preparing state
        allow_any_instance_of(AnalysisJob).to receive(:prepare!).and_return(true)

        analysis_job
      end

      it 'is :new after just being created' do
        expect(analysis_job).to be_new
      end

      it 'has the correct progress statistics' do
        test_stats(analysis_job)
      end

      it 'ensures no new jobs exist in the message queue' do
        expect_queue_count(queue_name, 0)
        expect_failed_queue_count(0)
      end

      it 'ensures no new AnalysisJobsItems exist' do
        expect(job_items_count).to eq(0)
      end
    end

    describe 'status: "preparing"' do
      let(:analysis_job) { create_analysis_job }

      before do
        ActionMailer::Base.deliveries.clear

        # stub batch-size so we so batches that are relevant to our test case.
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        # don't allow automatic transition to :processing state
        allow_any_instance_of(AnalysisJob).to receive(:process!).and_wrap_original do |m, *_args|
          m.receiver.send(:update_job_progress)
          m.receiver.save!
        end

        analysis_job
      end

      after do
        clear_pending_jobs
      end

      it 'emails the user when the job is starting to prepare' do
        mail = ActionMailer::Base.deliveries.last

        expect(mail['to'].to_s).to include(writer_user.email)
        expect(mail['subject'].value).to include(analysis_job.name)
        expect(mail['subject'].value).to include('New job')
        expect(mail.body.raw_source).to include("ID: #{analysis_job.id}")
        expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{analysis_job.id}")
      end

      it 'is :preparing when preparing' do
        expect(analysis_job).to be_preparing
      end

      it 'has the correct progress statistics' do
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 6,
            working: 0,
            successful: 0,
            failed: 0,
            total: 6
          }
        }, 6)
      end

      it 'ensures new job items exist in the message queue' do
        expect_queue_count(queue_name, 6)
        expect_failed_queue_count(0)
      end

      it 'ensures new AnalysisJobsItems exist' do
        expect(job_items_count).to eq(6)
      end
    end

    describe 'distributed patterns, "preparing" -> "completed"', web_server_timeout: 120 do
      expose_app_as_web_server

      let(:analysis_job) { create_analysis_job_direct }

      it 'allows for some jobs items to have be started while still preparing' do
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        # hook in and run one job for every batch
        # we're simulating a distributed system here
        # for each two recordings added, process one afterwards
        # i.e. prepare 1,2; run 1; prepare 3,4; run 2; prepare 5,6; run 3;
        allow(analysis_job).to receive(:prepare_analysis_job_item).and_wrap_original do |m, *args|
          result = m.call(*args)

          # what ever is next on the queue - two should have just been added, so do two
          perform_jobs_immediately(count: 1)
          result
        end

        # actually kick off the prepare
        analysis_job.prepare!

        # wait for any stragglers
        wait_for_jobs

        analysis_job.reload

        expect_queue_count(queue_name, 3)
        expect_failed_queue_count(0)

        expect(job_items_count).to eq(6)

        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 3,
            working: 0,
            successful: 3,
            failed: 0,
            total: 6
          }
        }, 6)

        expect(analysis_job).to be_processing

        clear_pending_jobs
      end

      it 'allows for all jobs items to have completed while still preparing - and to skip `processing` completely' do
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        # hook in and run one job for every batch
        # we're simulating a distributed system here
        # for each two recordings added, process one afterwards
        # i.e. prepare 1,2; run 1,2; prepare 3,4; run 3,4; prepare 5,6; run 5,6;
        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        allow(analysis_job).to receive(:prepare_analysis_job_item).and_wrap_original do |m, *args|
          result = m.call(*args)

          # what ever is next on the queue - two should have just been added, so do two
          perform_jobs_immediately(count: 2)
          result
        end

        # actually kick off the prepare
        analysis_job.prepare!

        # wait for any stragglers
        wait_for_jobs

        analysis_job.reload

        expect_queue_count(queue_name, 0)
        expect_failed_queue_count(0)

        expect(job_items_count).to eq(6)

        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            working: 0,
            successful: 6,
            failed: 0,
            total: 6
          }
        }, 6)

        expect(analysis_job).to be_completed
      end
    end

    describe 'status: "processing"' do
      expose_app_as_web_server
      ignore_pending_jobs
      let(:analysis_job) { create_analysis_job }

      before do
        # here we simulate a system with a variety of sub-statuses
        states = [
          [true, nil], # 'working'
          [false, 'successful'],
          [false, 'timed_out'],
          [false, 'failed'],
          # the following two aren't run
          [false, 'successful'],
          [true, nil]
        ]
        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          mock_behaviour = states.shift

          # augment the hash
          args[0][:skip_completion] = mock_behaviour[0]
          args[0][:mock_result] = mock_behaviour[1]

          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        analysis_job

        # pause time
        #Timecop.freeze

        # start 4/6 of actions
        perform_jobs(count: 4)
      end

      it 'is :processing when processing' do
        expect(analysis_job).to be_processing
      end

      it 'ensures some jobs exist in the message queue' do
        expect_queue_count(queue_name, 2)
        expect_failed_queue_count(1)
      end

      it 'ensures all AnalysisJobsItems exist' do
        expect(job_items_count).to eq(6)
      end

      it 'correctly reports progress statistics' do
        #  it 'allows for jobs items to have all different states'
        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
      end

      it 'invalidates cached progress statistics every whenever an analysis_job_item is updated' do
        updated_at = analysis_job.updated_at

        # stats shouldn't have changed
        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(analysis_job.updated_at).to eq(updated_at)

        # complete a job to finish
        perform_jobs(count: 1)

        # reload to see the change
        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 1,
            working: 1,
            successful: 2,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(analysis_job.updated_at).to eq(updated_at)

        # start another job - do not complete (see `states` in before(:each))
        perform_jobs(count: 1)

        # reload to see the change
        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            working: 2,
            successful: 2,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(analysis_job.updated_at).to eq(updated_at)
      end
    end

    describe 'status: "suspended"' do
      expose_app_as_web_server
      ignore_pending_jobs

      let(:analysis_job) { create_analysis_job }

      before do
        # here we simulate a system with a variety of sub-statuses
        # [skip_completion, mock_result, good_cancel_behaviour]
        states = [
          [true, nil], # 'working'
          [false, 'successful'],
          [false, 'timed_out'],
          [false, 'failed'],
          # the following two aren't run
          [false, 'successful', true],
          [false, 'successful', true]
        ]

        @working_audio_recording_id

        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          mock_behaviour = states.shift

          # augment the hash
          args[0][:skip_completion] = mock_behaviour[0]
          args[0][:mock_result] = mock_behaviour[1]
          args[0][:good_cancel_behaviour] = mock_behaviour[2] || false

          @working_audio_recording_id = args[0][:id] if @working_audio_recording_id.nil?

          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        analysis_job

        # start 4/6 of actions
        perform_jobs(count: 4)
        expect_queue_count(queue_name, 2)
        expect_failed_queue_count(1)
        expect(job_items_count).to eq(6)
        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)

        update_analysis_job(analysis_job.id, 'suspended')
        analysis_job.reload
      end

      it 'is :suspended when suspended' do
        expect(analysis_job).to be_suspended
      end

      it 'DOES NOTHING to the items in to the message queue' do
        expect_queue_count(queue_name, 2)
        expect_failed_queue_count(1)
      end

      it 'ensures all AnalysisJobsItems that are :queued are reset to :cancelling' do
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)

        expect(job_items_count).to eq(6)
        expect(job_items_count('cancelling')).to eq(2)
      end

      it 'will let job items finish (i.e. race conditions)' do
        update_analysis_job_item(analysis_job.id, @working_audio_recording_id, 'successful')

        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 2,
            working: 0,
            successful: 2,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
      end

      it 'confirms cancellation when the job tries to run (:cancelling --> :cancelled)' do
        perform_jobs(count: 2)

        # no more jobs are left
        expect_queue_count(queue_name, 0)

        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 2,
            cancelling: 0,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
      end

      it 'can not resume when items are still queued' do
        item = AnalysisJobsItem.first
        # skip callbacks, validations, ActiveModelBase, etc...
        item.update_column(:status, 'queued')

        analysis_job.reload

        expect {
          analysis_job.resume
        }.to raise_error(AASM::InvalidTransition)
      end

      describe 'status: "suspended"→"processing"' do
        ignore_pending_jobs
        before do
          # reset our mocks, or else create_payload will be mocked again!
          RSpec::Mocks.space.proxy_for(BawWorkers::Jobs::Analysis::Job).reset

          expect(job_items_count).to eq(6)
          expect(job_items_count('cancelling')).to eq(2)

          @old_items = AnalysisJobsItem.where(status: 'cancelling').to_a

          # perform one outlying job (--> :cancelled), leave one :cancelling
          perform_jobs(count: 1)

          expect_queue_count(queue_name, 1)
          expect_failed_queue_count(1)

          analysis_job.reload
          test_stats_for(analysis_job, {
            overall_progress: {
              queued: 0,
              cancelled: 1,
              cancelling: 1,
              working: 1,
              successful: 1,
              failed: 1,
              timed_out: 1,
              total: 6
            }
          }, 6)

          # resume job
          update_analysis_job(analysis_job.id, 'processing')

          analysis_job.reload
        end

        it 'is :processing when processing' do
          expect(analysis_job).to be_processing
        end

        it 'ADDs all :cancelled jobs items in to the message queue' do
          expect_queue_count(queue_name, 2)
          expect_failed_queue_count(1)
        end

        it 'ensures all AnalysisJobsItems that are :cancelled are reset to :queued (and get updated job ids)' do
          expect(job_items_count).to eq(6)
          expect(job_items_count('cancelled')).to eq(0)
          expect(job_items_count('cancelling')).to eq(0)
          expect(job_items_count('queued')).to eq(2)

          # expect first item (which was cancelled to get a new queue_id)
          expect(@old_items[0].queue_id).not_to eq(AnalysisJobsItem.find(@old_items[0].id).queue_id)

          # expect second one to have its old id
          expect(@old_items[1].queue_id).to eq(AnalysisJobsItem.find(@old_items[1].id).queue_id)
        end

        it 'has the correct progress statistics' do
          test_stats_for(analysis_job, {
            overall_progress: {
              queued: 2,
              working: 1,
              successful: 1,
              failed: 1,
              timed_out: 1,
              total: 6
            }
          }, 6)
        end
      end
    end

    describe 'status: "completed"' do
      expose_app_as_web_server
      ignore_pending_jobs

      let(:analysis_job) { create_analysis_job }

      before do
        # here we simulate a system with a variety of sub-statuses
        # [skip_completion, mock_result, good_cancel_behaviour]
        states = [
          [false, 'successful'],
          [false, 'successful'],
          [false, 'timed_out'],
          [false, 'failed'],
          [false, 'successful'],
          [false, 'successful']
        ]

        @working_audio_recording_id
        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          mock_behaviour = states.shift

          # augment the hash
          args[0][:skip_completion] = mock_behaviour[0]
          args[0][:mock_result] = mock_behaviour[1]

          @working_audio_recording_id = args[0][:id] if @working_audio_recording_id.nil?

          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        analysis_job

        # start all actions - and complete the job!
        perform_jobs(count: 6)

        analysis_job.reload
      end

      it 'is :completed when completed' do
        expect(analysis_job).to be_completed
      end

      it 'ensures NO jobs exist in the message queue' do
        expect_queue_count(queue_name, 0)
        expect_failed_queue_count(1)
      end

      it 'ensures all AnalysisJobsItems have one of the completed statuses' do
        expect(job_items_count).to eq(6)
        expect(AnalysisJobsItem.completed_for_analysis_job(analysis_job.id).count).to eq(6)
      end

      it 'correctly updates progress statistics' do
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 0,
            working: 0,
            successful: 4,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
      end

      it 'emails the user when the job is complete' do
        mail = ActionMailer::Base.deliveries.last

        expect(mail['to'].to_s).to include(writer_user.email)
        expect(mail['subject'].value).to include(analysis_job.name)
        expect(mail['subject'].value).to include('Completed job')
        expect(mail.body.raw_source).to include("ID: #{analysis_job.id}")
        expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{analysis_job.id}")
      end

      describe 'retrying failed items, status: "completed"→"processing"' do
        before do
          # reset our mocks, or else create_payload will be mocked again!
          RSpec::Mocks.space.proxy_for(BawWorkers::Jobs::Analysis::Job).reset

          allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
            m.call(*args.push(Fixtures::FakeAnalysisJob))
          end

          # fake a cancelled item
          item = AnalysisJobsItem.for_analysis_job(analysis_job.id).where(status: 'successful').first
          item.update_column(:status, 'cancelled')
          analysis_job.check_progress

          @old_items = AnalysisJobsItem.where(status: ['timed_out', 'failed', 'cancelled']).to_a

          expect_queue_count(queue_name, 0)
          expect_failed_queue_count(1)

          test_stats_for(analysis_job, {
            overall_progress: {
              queued: 0,
              cancelled: 1,
              cancelling: 0,
              working: 0,
              successful: 3,
              failed: 1,
              timed_out: 1,
              total: 6
            }
          }, 6)

          # resume job
          update_analysis_job(analysis_job.id, 'processing')

          analysis_job.reload
        end

        it 'is :processing when processing' do
          expect(analysis_job).to be_processing
        end

        it 'ADDs all :cancelled jobs items in to the message queue' do
          expect_queue_count(queue_name, 3)
          expect_failed_queue_count(1)
        end

        it 'ensures all AnalysisJobsItems that are failed are reset to :queued (and get updated job ids)' do
          expect(job_items_count).to eq(6)
          expect(job_items_count('cancelled')).to eq(0)
          expect(job_items_count('cancelling')).to eq(0)
          expect(job_items_count('queued')).to eq(3)

          @old_items.each do |item|
            expect(item.queue_id).not_to eq(AnalysisJobsItem.find(item.id).queue_id)
          end
        end

        it 'has the correct progress statistics' do
          test_stats_for(analysis_job, {
            overall_progress: {
              queued: 3,
              working: 0,
              successful: 3,
              failed: 0,
              timed_out: 0,
              total: 6
            }
          }, 6)
        end

        it 'emails the user when the job has been retried' do
          mail = ActionMailer::Base.deliveries.last

          expect(mail['to'].to_s).to include(writer_user.email)
          expect(mail['subject'].value).to include(analysis_job.name)
          expect(mail['subject'].value).to include('Retrying job')
          expect(mail.body.raw_source).to include("ID: #{analysis_job.id}")
          expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{analysis_job.id}")
        end

        it 'can still complete!' do
          perform_jobs(count: 3)

          analysis_job.reload
          expect(analysis_job).to be_completed
          expect_queue_count(queue_name, 0)
          expect_failed_queue_count(1)

          test_stats_for(analysis_job, {
            overall_progress: {
              queued: 0,
              working: 0,
              successful: 6,
              failed: 0,
              timed_out: 0,
              total: 6
            }
          }, 6)

          mail = ActionMailer::Base.deliveries.last

          expect(mail['to'].to_s).to include(writer_user.email)
          expect(mail['subject'].value).to include(analysis_job.name)
          expect(mail['subject'].value).to include('Completed job')
          expect(mail.body.raw_source).to include("ID: #{analysis_job.id}")
          expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{analysis_job.id}")
        end
      end
    end
  end

  describe 'Deleting an analysis job' do
    expose_app_as_web_server

    describe 'status: "new"' do
      let(:analysis_job) { create_analysis_job_direct }

      before do
        expect(analysis_job).to be_new
      end

      it 'cannot be deleted while new' do
        status_code, response = destroy_analysis_job(analysis_job.id)

        expect(status_code).to be(409)
        expect(response.body).to include('Cannot be deleted while `overall_status` is `new`')
      end
    end

    describe 'status: "preparing"' do
      let!(:analysis_job) { create_analysis_job_direct }

      before do
        # don't allow automatic transition to :processing state
        allow_any_instance_of(AnalysisJob).to receive(:process!).and_wrap_original do |m, *_args|
          m.receiver.send(:update_job_progress)
          m.receiver.save!
        end

        analysis_job.prepare!

        expect(analysis_job).to be_preparing
      end

      it 'cannot be deleted while preparing' do
        status_code, response = destroy_analysis_job(analysis_job.id)

        expect(status_code).to be(409)
        expect(response.body).to include('Cannot be deleted while `overall_status` is `preparing`')

        clear_pending_jobs
      end
    end

    describe 'status: "processing"' do
      let!(:analysis_job) { create_analysis_job }

      ignore_pending_jobs

      before do
        expect(analysis_job).to be_processing

        status_code, _response = destroy_analysis_job(analysis_job.id)
        expect(status_code).to eq(204)

        analysis_job.reload
      end

      it 'is :suspended when deleted' do
        expect(analysis_job).to be_suspended
      end
    end

    describe 'status: "suspended"' do
      ignore_pending_jobs
      let(:analysis_job) { create_analysis_job }

      before do
        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        expect(analysis_job).to be_processing

        status_code, _response = destroy_analysis_job(analysis_job.id)
        expect(status_code).to eq(204)

        analysis_job.reload
      end

      it 'is :suspended when deleted' do
        expect(analysis_job).to be_suspended
      end

      it 'DOES NOT change the message queue' do
        expect_queue_count(queue_name, 6)
      end

      it 'cancels all remaining AnalysisJobsItems that exist' do
        expect(job_items_count).to eq(6)
        expect(job_items_count('cancelled')).to eq(0)
        expect(job_items_count('cancelling')).to eq(6)
      end

      it 'correctly reports progress statistics' do
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 6,
            working: 0,
            successful: 0,
            failed: 0,
            timed_out: 0,
            total: 6
          }
        }, 6)
      end

      it 'will let job items finish (race conditions)' do
        # fake the first job as working already
        item = AnalysisJobsItem.first
        # skip validations, save directly to database
        item.update_column(:status, 'working')

        update_analysis_job_item(analysis_job.id, item.audio_recording_id, 'successful')

        item.reload
        expect(item).to be_successful

        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 5,
            working: 0,
            successful: 1,
            failed: 0,
            timed_out: 0,
            total: 6
          }
        }, 6)

        expect(analysis_job.deleted?).to be(true)
      end

      it 'will let job items cancel (race conditions, message queue depletion)' do
        perform_jobs(count: 1)
        item = get_analysis_job_item(analysis_job.id, AnalysisJobsItem.first.audio_recording_id)
        expect(item['data']['status']).to eq('cancelled')

        expect(job_items_count).to eq(6)
        expect(job_items_count('cancelled')).to eq(1)
        expect(job_items_count('cancelling')).to eq(5)

        expect_queue_count(queue_name, 5)
        #expect_failed_queue_count(1)

        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 1,
            cancelling: 5,
            working: 0,
            successful: 0,
            failed: 0,
            timed_out: 0,
            total: 6
          }
        }, 6)

        expect(analysis_job.deleted?).to be(true)
      end

      it 'will let all job items complete (message queue depletion) - but it wont transition to :complete!' do
        perform_jobs(count: 6)

        expect(job_items_count).to eq(6)
        expect(job_items_count('cancelled')).to eq(6)
        expect(job_items_count('cancelling')).to eq(0)

        expect_queue_count(queue_name, 0)
        #expect_failed_queue_count(6)

        analysis_job.reload
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 6,
            cancelling: 0,
            working: 0,
            successful: 0,
            failed: 0,
            timed_out: 0,
            total: 6
          }
        }, 6)

        expect(analysis_job).to be_suspended
        expect(analysis_job.deleted?).to be(true)

        mail = ActionMailer::Base.deliveries.last
        expect(mail['subject'].value).not_to include('Completed analysis job')
      end
    end

    describe 'status: "completed"' do
      ignore_pending_jobs
      let(:analysis_job) { create_analysis_job }

      before do
        allow(BawWorkers::Jobs::Analysis::Job).to receive(:action_enqueue).and_wrap_original do |m, *args|
          m.call(*args.push(Fixtures::FakeAnalysisJob))
        end

        analysis_job

        perform_jobs(count: 6)

        status_code, _response = destroy_analysis_job(analysis_job.id)
        expect(status_code).to eq(204)

        analysis_job.reload

        expect(analysis_job.deleted?).to be(true)
      end

      it 'is :completed when deleted' do
        expect(analysis_job).to be_completed
      end

      it 'has no job items to remove from the message queue' do
        expect_queue_count(queue_name, 0)
        expect_failed_queue_count(0)
      end

      it 'ensures there are no non-completed AnalysisJobsItems statuses' do
        expect(job_items_count).to eq(6)
        expect(job_items_count('successful')).to eq(6)
      end

      it 'correctly updates progress statistics' do
        test_stats_for(analysis_job, {
          overall_progress: {
            queued: 0,
            cancelled: 0,
            cancelling: 0,
            working: 0,
            successful: 6,
            failed: 0,
            timed_out: 0,
            total: 6
          }
        }, 6)
      end
    end
  end
end
