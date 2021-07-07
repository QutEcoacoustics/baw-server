# frozen_string_literal: true

require 'helpers/resque_helpers'
require 'rspec/mocks'

#
# Integration testing of AnalysisJobsController controller.
# API level tests should be put in acceptance/analysis_jobs_spec.rb
#

describe 'Analysis Jobs' do
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
    Creation::Common.create_saved_search(writer_user, project,
                                         site_id: { eq: site.id })
  }

  let!(:script) {
    FactoryBot.create(
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

  before(:all) do
    @default_queue = Settings.actions.analysis.queue
    @manual_queue = @default_queue
    @queue_name = @manual_queue

    # cleanup resque queues before each test
    BawWorkers::ResqueApi.clear_queue(@default_queue)
    BawWorkers::ResqueApi.clear_queue(@manual_queue)
    Resque::Failure.clear

    # process one fake job so that the queue exists!
    options = {
      queue: @queue_name,
      verbose: true,
      fork: false
    }
    @worker, _job = ResqueHelpers::Emulate.resque_worker_with_job(FakeJob, { an_argument: 3 }, options)
  end

  before do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = writer_token

    @analysis_job_url = '/analysis_jobs'
  end

  after do |example|
    if example.exception
      require 'json'

      ajids = AnalysisJob.all.join(', ')
      ajis = AnalysisJobsItem.all.join('\n\t- ')

      puts <<~DEBUGMESSAGE
        Queue name: #{@queue_name}
        Queue count: #{get_queue_count}
        Failure count: #{get_failed_queue_count}
        All analysis job ids: #{ajids}
        All analysis job items:\n#{ajis}
      DEBUGMESSAGE
    end
  end

  def reset
    BawWorkers::ResqueApi.clear_queue(@queue_name)
    Resque::Failure.clear
  end

  def get_queue_count
    Resque.size(@queue_name)
  end

  def get_failed_queue_count
    Resque::Failure.count
  end

  def get_items_count(status = nil)
    predicates = { analysis_job_id: @analysis_job.id }
    predicates[:status] = status if status
    AnalysisJobsItem.where(predicates).count
  end

  def create_analysis_job
    this_script = script
    puts "creating analysis job using script with id #{this_script.id} and settings '#{this_script.executable_settings}'"
    valid_attributes = {
      analysis_job: {
        script_id: this_script.id,
        saved_search_id: saved_search.id,
        name: "Analysis Job ##{Time.now}",
        custom_settings: this_script.executable_settings,
        description: 'Description...'
      }
    }

    post @analysis_job_url, params: valid_attributes, headers: @env

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

    @env['HTTP_AUTHORIZATION'] = writer_token

    put update_route, params: {
      analysis_job: {
        overall_status: overall_status
      }
    }, headers: @env

    raise "Failed to update AnalysisJob, status: #{response.status}" if response.status != 200
  end

  def destroy_analysis_job(analysis_job_id)
    destroy_route = "/analysis_jobs/#{analysis_job_id}"

    @env['HTTP_AUTHORIZATION'] = writer_token

    delete destroy_route, params: {}, headers: @env

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

    # only the harvester user can update job items!
    @env['HTTP_AUTHORIZATION'] = harvester_token
    @env['HTTP_ACCEPT'] = 'application/json'

    get route, params: {}, headers: @env

    raise "Failed to get AnalysisJobItem, status: #{response.status}" if response.status != 200

    JSON.parse(response.body)
  end

  def update_analysis_job_item(analysis_job_id, audio_recording_id, status)
    update_route = "/analysis_jobs/#{analysis_job_id}/audio_recordings/#{audio_recording_id}"

    # only the harvester user can update job items!
    @env['HTTP_AUTHORIZATION'] = harvester_token
    @env['HTTP_ACCEPT'] = 'application/json'

    put update_route, params: {
      analysis_jobs_item: {
        status: status
      }
    }, headers: @env

    if response.status != 200
      raise "Failed to update AnalysisJobItem, status: #{response.status} #{response.message}\n#{response.body}"
    end
  end

  class FakeAnalysisJob
    include ActionDispatch::Integration::RequestHelpers

    # super hacky way to inject test-context into this class
    class_attribute :test_instance

    def self.perform(resque_id, params)
      analysis_params = params['analysis_params']
      mock_result = analysis_params['mock_result'] || 'successful'
      skip_completion = analysis_params['skip_completion'] == true
      good_cancel_behaviour = analysis_params['good_cancel_behaviour'] == true

      analysis_job_id = analysis_params['job_id']
      audio_recording_id = analysis_params['id']

      # simulate the working call
      if good_cancel_behaviour
        status = test_instance.get_analysis_job_item(analysis_job_id, audio_recording_id)['data']['status']
        if status == 'cancelling'
          test_instance.update_analysis_job_item(analysis_job_id, audio_recording_id, 'cancelled')
          return
        else
          test_instance.update_analysis_job_item(analysis_job_id, audio_recording_id, 'working')
        end
      else
        test_instance.update_analysis_job_item(analysis_job_id, audio_recording_id, 'working')
      end

      # do some work
      work = {
        resque_id: resque_id,
        params: params,
        result: Time.now
      }

      unless skip_completion
        # simulate the complete call
        test_instance.update_analysis_job_item(analysis_job_id, audio_recording_id, mock_result)

        raise 'Fake analysis job failing on purpose' if mock_result == 'failed'
      end
    end

    def self.on_failure(*args)
      test_instance.job_perform_failure = args
    end
  end

  attr_writer :job_perform_failure

  def perform_job
    @job_perform_failure = nil

    # execute the next available job
    FakeAnalysisJob.test_instance = self
    ResqueHelpers::Emulate.resque_worker(@queue_name, true, false, 'FakeAnalysisJob')

    if @job_perform_failure && @job_perform_failure[0].message != 'Fake analysis job failing on purpose'

      message = @job_perform_failure if @job_perform_failure.is_a? String
      message = @job_perform_failure.join("\n") if @job_perform_failure.is_a? Array
      if @job_perform_failure.is_a? Exception
        message = @job_perform_failure.full_message
        message += @job_perform_failure.backtrace.join('\n')
      end

      raise "job perform failed: #{message}"
    end
  end

  describe 'Creating an analysis job' do
    describe 'status: "new"' do
      before do
        reset

        # stub the prepare_job method so that it is a no-op
        # so we can test :new in isolation
        allow_any_instance_of(AnalysisJob).to receive(:prepare!).and_return([])
        allow_any_instance_of(AnalysisJob).to receive(:prepare).and_return([])

        @analysis_job = create_analysis_job
      end

      it 'is :new after just being created' do
        expect(@analysis_job).to be_new
      end

      it 'has the correct progress statistics' do
        test_stats(@analysis_job)
      end

      it 'ensures no new jobs exist in the message queue' do
        expect(get_queue_count).to eq(0)
        expect(get_failed_queue_count).to eq(0)
      end

      it 'ensures no new AnalysisJobsItems exist' do
        expect(get_items_count).to eq(0)
      end
    end

    describe 'status: "preparing"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear

        # stub batch-size so we so batches that are relevant to our test case.
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        # don't allow automatic transition to :processing state
        allow_any_instance_of(AnalysisJob).to receive(:process!).and_wrap_original do |m, *_args|
          m.receiver.send(:update_job_progress)
          m.receiver.save!
        end

        @analysis_job = create_analysis_job
      end

      it 'emails the user when the job is starting to prepare' do
        mail = ActionMailer::Base.deliveries.last

        expect(mail['to'].to_s).to include(writer_user.email)
        expect(mail['subject'].value).to include(@analysis_job.name)
        expect(mail['subject'].value).to include('New job')
        expect(mail.body.raw_source).to include("ID: #{@analysis_job.id}")
        expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{@analysis_job.id}")
      end

      it 'is :preparing when preparing' do
        expect(@analysis_job).to be_preparing
      end

      it 'has the correct progress statistics' do
        test_stats_for(@analysis_job, {
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
        expect(get_queue_count).to eq(6)
        expect(get_failed_queue_count).to eq(0)
      end

      it 'ensures new AnalysisJobsItems exist' do
        expect(get_items_count).to eq(6)
      end
    end

    describe 'distributed patterns, "preparing" -> "completed"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear
      end

      it 'allows for some jobs items to have be started while still preparing' do
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        @analysis_job = create_analysis_job_direct

        # hook in and run one job for every batch
        # we're simulating a distributed system here
        # for each two recordings added, process one afterwards
        # i.e. prepare 1,2; run 1; prepare 3,4; run 2; prepare 5,6; run 3;
        allow(@analysis_job).to receive(:prepare_analysis_job_item).and_wrap_original do |m, *args|
          result = m.call(*args)

          # what ever is next on the queue ( but just 1)
          perform_job

          result
        end

        # actually kick off the prepare
        @analysis_job.prepare!

        expect(get_queue_count).to eq(3)
        expect(get_failed_queue_count).to eq(0)

        expect(get_items_count).to eq(6)

        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 3,
            working: 0,
            successful: 3,
            failed: 0,
            total: 6
          }
        }, 6)

        expect(@analysis_job).to be_processing
      end

      it 'allows for all jobs items to have completed while still preparing - and to skip `processing` completely' do
        allow(AnalysisJob).to receive(:batch_size).and_return(2)

        @analysis_job = create_analysis_job_direct

        # hook in and run one job for every batch
        # we're simulating a distributed system here
        # for each two recordings added, process one afterwards
        # i.e. prepare 1,2; run 1,2; prepare 3,4; run 3,4; prepare 5,6; run 5,6;
        allow(@analysis_job).to receive(:prepare_analysis_job_item).and_wrap_original do |m, *args|
          result = m.call(*args)

          # what ever is next on the queue - two should have just been added, so do two
          perform_job
          perform_job

          result
        end

        # actually kick off the prepare
        @analysis_job.prepare!

        expect(get_queue_count).to eq(0)
        expect(get_failed_queue_count).to eq(0)

        expect(get_items_count).to eq(6)

        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 0,
            working: 0,
            successful: 6,
            failed: 0,
            total: 6
          }
        }, 6)

        expect(@analysis_job).to be_completed
      end
    end

    describe 'status: "processing"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear

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

        allow(AnalysisJobsItem).to receive(:create_action_payload).and_wrap_original do |m, *args|
          result = m.call(*args)

          mock_behaviour = states.shift

          # augment the hash
          result[:skip_completion] = mock_behaviour[0]
          result[:mock_result] = mock_behaviour[1]

          result
        end

        @analysis_job = create_analysis_job

        # pause time
        #Timecop.freeze

        # start 4/6 of actions
        4.times { perform_job }
      end

      it 'is :processing when processing' do
        expect(@analysis_job).to be_processing
      end

      it 'ensures some all jobs exist in the message queue' do
        expect(get_queue_count).to eq(2)
        expect(get_failed_queue_count).to eq(1)
      end

      it 'ensures all AnalysisJobsItems exist' do
        expect(get_items_count).to eq(6)
      end

      it 'correctly reports progress statistics' do
        #  it 'allows for jobs items to have all different states'
        @analysis_job.reload
        test_stats_for(@analysis_job, {
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
        updated_at = @analysis_job.updated_at

        # stats shouldn't have changed
        @analysis_job.reload
        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(@analysis_job.updated_at).to eq(updated_at)

        # complete a job to finish
        perform_job

        # reload to see the change
        @analysis_job.reload
        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 1,
            working: 1,
            successful: 2,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(@analysis_job.updated_at).to eq(updated_at)

        # start another job - do not complete (see `states` in before(:each))
        perform_job

        # reload to see the change
        @analysis_job.reload
        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 0,
            working: 2,
            successful: 2,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)
        expect(@analysis_job.updated_at).to eq(updated_at)
      end
    end

    describe 'status: "suspended"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear

        # here we simulate a system with a variety of sub-statuses
        # [skip_completion, mock_result, good_cancel_behaviour]
        states = [
          [true, nil], # 'working'
          [false, 'successful'],
          [false, 'timed_out'],
          [false, 'failed'],
          # the following two aren't run
          [false, 'successful', true],
          [true, 'successful']
        ]

        @working_audio_recording_id

        allow(AnalysisJobsItem).to receive(:create_action_payload).and_wrap_original do |m, *args|
          result = m.call(*args)

          mock_behaviour = states.shift

          # augment the hash
          result[:skip_completion] = mock_behaviour[0]
          result[:mock_result] = mock_behaviour[1]
          result[:good_cancel_behaviour] = mock_behaviour[2] || false

          @working_audio_recording_id = result[:id] if @working_audio_recording_id.nil?

          result
        end

        @analysis_job = create_analysis_job

        # start 4/6 of actions
        4.times do perform_job end

        expect(get_queue_count).to eq(2)
        expect(get_failed_queue_count).to eq(1)
        expect(get_items_count).to eq(6)
        @analysis_job.reload
        test_stats_for(@analysis_job, {
          overall_progress: {
            queued: 2,
            working: 1,
            successful: 1,
            failed: 1,
            timed_out: 1,
            total: 6
          }
        }, 6)

        update_analysis_job(@analysis_job.id, 'suspended')
        @analysis_job.reload
      end

      it 'is :suspended when suspended' do
        expect(@analysis_job).to be_suspended
      end

      it 'DOES NOTHING to the items in to the message queue' do
        expect(get_queue_count).to eq(2)
        expect(get_failed_queue_count).to eq(1)
      end

      it 'ensures all AnalysisJobsItems that are :queued are reset to :cancelling' do
        test_stats_for(@analysis_job, {
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

        expect(get_items_count).to eq(6)
        expect(get_items_count('cancelling')).to eq(2)
      end

      it 'will let job items finish (i.e. race conditions)' do
        update_analysis_job_item(@analysis_job.id, @working_audio_recording_id, 'successful')

        @analysis_job.reload
        test_stats_for(@analysis_job, {
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
        perform_job

        expect {
          perform_job
        }.to raise_error(RuntimeError, /Failed to update AnalysisJobItem, status: 422/)

        # no more jobs are left, this should be a no-op
        perform_job

        @analysis_job.reload
        test_stats_for(@analysis_job, {
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

        @analysis_job.reload

        expect {
          @analysis_job.resume
        }.to raise_error(AASM::InvalidTransition)
      end

      describe 'status: "suspended"→"processing"' do
        before do
          #reset
          # reset our mocks, or else create_payload will be mocked again!
          RSpec::Mocks.space.proxy_for(AnalysisJobsItem).reset

          expect(get_items_count).to eq(6)
          expect(get_items_count('cancelling')).to eq(2)

          @old_items = AnalysisJobsItem.where(status: 'cancelling').to_a

          # perform one outlying job (--> :cancelled), leave one :cancelling
          perform_job

          expect(get_queue_count).to eq(1)
          expect(get_failed_queue_count).to eq(1)

          @analysis_job.reload
          test_stats_for(@analysis_job, {
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
          update_analysis_job(@analysis_job.id, 'processing')

          @analysis_job.reload
        end

        it 'is :processing when processing' do
          expect(@analysis_job).to be_processing
        end

        it 'ADDs all :cancelled jobs items in to the message queue' do
          expect(get_queue_count).to eq(2)
          expect(get_failed_queue_count).to eq(1)
        end

        it 'ensures all AnalysisJobsItems that are :cancelled are reset to :queued (and get updated job ids)' do
          expect(get_items_count).to eq(6)
          expect(get_items_count('cancelled')).to eq(0)
          expect(get_items_count('cancelling')).to eq(0)
          expect(get_items_count('queued')).to eq(2)

          # expect first item (which was cancelled to get a new queue_id)
          expect(@old_items[0].queue_id).not_to eq(AnalysisJobsItem.find(@old_items[0].id).queue_id)

          # expect second one to have its old id
          expect(@old_items[1].queue_id).to eq(AnalysisJobsItem.find(@old_items[1].id).queue_id)
        end

        it 'has the correct progress statistics' do
          test_stats_for(@analysis_job, {
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
      before do
        reset
        ActionMailer::Base.deliveries.clear

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

        allow(AnalysisJobsItem).to receive(:create_action_payload).and_wrap_original do |m, *args|
          result = m.call(*args)

          mock_behaviour = states.shift

          # augment the hash
          result[:skip_completion] = mock_behaviour[0]
          result[:mock_result] = mock_behaviour[1]

          result
        end

        @analysis_job = create_analysis_job

        # start all actions - and complete the job!
        6.times do perform_job end

        @analysis_job.reload
      end

      it 'is :completed when completed' do
        expect(@analysis_job).to be_completed
      end

      it 'ensures NO jobs exist in the message queue' do
        expect(get_queue_count).to eq(0)
        expect(get_failed_queue_count).to eq(1)
      end

      it 'ensures all AnalysisJobsItems have one of the completed statuses' do
        expect(get_items_count).to eq(6)
        expect(AnalysisJobsItem.completed_for_analysis_job(@analysis_job.id).count).to eq(6)
      end

      it 'correctly updates progress statistics' do
        test_stats_for(@analysis_job, {
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
        expect(mail['subject'].value).to include(@analysis_job.name)
        expect(mail['subject'].value).to include('Completed job')
        expect(mail.body.raw_source).to include("ID: #{@analysis_job.id}")
        expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{@analysis_job.id}")
      end

      describe 'retrying failed items, status: "completed"→"processing"' do
        before do
          #reset
          ActionMailer::Base.deliveries.clear

          # reset our mocks, or else create_payload will be mocked again!
          RSpec::Mocks.space.proxy_for(AnalysisJobsItem).reset

          # fake a cancelled item
          item = AnalysisJobsItem.for_analysis_job(@analysis_job.id).where(status: 'successful').first
          item.update_column(:status, 'cancelled')
          @analysis_job.check_progress

          @old_items = AnalysisJobsItem.where(status: ['timed_out', 'failed', 'cancelled']).to_a

          expect(get_queue_count).to eq(0)
          expect(get_failed_queue_count).to eq(1)

          test_stats_for(@analysis_job, {
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
          update_analysis_job(@analysis_job.id, 'processing')

          @analysis_job.reload
        end

        it 'is :processing when processing' do
          expect(@analysis_job).to be_processing
        end

        it 'ADDs all :cancelled jobs items in to the message queue' do
          expect(get_queue_count).to eq(3)
          expect(get_failed_queue_count).to eq(1)
        end

        it 'ensures all AnalysisJobsItems that are failed are reset to :queued (and get updated job ids)' do
          expect(get_items_count).to eq(6)
          expect(get_items_count('cancelled')).to eq(0)
          expect(get_items_count('cancelling')).to eq(0)
          expect(get_items_count('queued')).to eq(3)

          @old_items.each do |item|
            expect(item.queue_id).not_to eq(AnalysisJobsItem.find(item.id).queue_id)
          end
        end

        it 'has the correct progress statistics' do
          test_stats_for(@analysis_job, {
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
          expect(mail['subject'].value).to include(@analysis_job.name)
          expect(mail['subject'].value).to include('Retrying job')
          expect(mail.body.raw_source).to include("ID: #{@analysis_job.id}")
          expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{@analysis_job.id}")
        end

        it 'can still complete!' do
          perform_job
          perform_job
          perform_job

          @analysis_job.reload
          expect(@analysis_job).to be_completed
          expect(get_queue_count).to eq(0)
          expect(get_failed_queue_count).to eq(1)

          test_stats_for(@analysis_job, {
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
          expect(mail['subject'].value).to include(@analysis_job.name)
          expect(mail['subject'].value).to include('Completed job')
          expect(mail.body.raw_source).to include("ID: #{@analysis_job.id}")
          expect(mail.body.raw_source).to include("localhost:3000/analysis_jobs/#{@analysis_job.id}")
        end
      end
    end
  end

  describe 'Deleting an analysis job' do
    describe 'status: "new"' do
      before do
        reset
        @analysis_job = create_analysis_job_direct

        expect(@analysis_job).to be_new
      end

      it 'cannot be deleted while new' do
        status_code, response = destroy_analysis_job(@analysis_job.id)

        expect(status_code).to be(409)
        expect(response.body).to include('Cannot be deleted while `overall_status` is `new`')
      end
    end

    describe 'status: "preparing"' do
      before do
        reset
        @analysis_job = create_analysis_job_direct

        # don't allow automatic transition to :processing state
        allow_any_instance_of(AnalysisJob).to receive(:process!).and_wrap_original do |m, *_args|
          m.receiver.send(:update_job_progress)
          m.receiver.save!
        end

        @analysis_job.prepare!

        expect(@analysis_job).to be_preparing
      end

      it 'cannot be deleted while preparing' do
        status_code, response = destroy_analysis_job(@analysis_job.id)

        expect(status_code).to be(409)
        expect(response.body).to include('Cannot be deleted while `overall_status` is `preparing`')
      end
    end

    describe 'status: "processing"' do
      before do
        reset
        @analysis_job = create_analysis_job

        expect(@analysis_job).to be_processing

        status_code, response = destroy_analysis_job(@analysis_job.id)
        expect(status_code).to eq(204)

        @analysis_job.reload
      end

      it 'is :suspended when deleted' do
        expect(@analysis_job).to be_suspended
      end
    end

    describe 'status: "suspended"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear

        @analysis_job = create_analysis_job

        expect(@analysis_job).to be_processing

        status_code, response = destroy_analysis_job(@analysis_job.id)
        expect(status_code).to eq(204)

        @analysis_job.reload
      end

      it 'is :suspended when deleted' do
        expect(@analysis_job).to be_suspended
      end

      it 'DOES NOT change the message queue' do
        expect(get_queue_count).to eq(6)
      end

      it 'cancels all remaining AnalysisJobsItems that exist' do
        expect(get_items_count).to eq(6)
        expect(get_items_count('cancelled')).to eq(0)
        expect(get_items_count('cancelling')).to eq(6)
      end

      it 'correctly reports progress statistics' do
        test_stats_for(@analysis_job, {
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

        update_analysis_job_item(@analysis_job.id, item.audio_recording_id, 'successful')

        item.reload
        expect(item).to be_successful

        @analysis_job.reload
        test_stats_for(@analysis_job, {
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

        expect(@analysis_job.deleted?).to eq(true)
      end

      it 'will let job items cancel (race conditions, message queue depletion)' do
        expect {
          perform_job
        }.to raise_error(RuntimeError, /Failed to update AnalysisJobItem, status: 422/)

        # side test, it can also get the status of an item even if parent job deleted
        item = get_analysis_job_item(@analysis_job.id, AnalysisJobsItem.first.audio_recording_id)
        expect(item['data']['status']).to eq('cancelled')

        expect(get_items_count).to eq(6)
        expect(get_items_count('cancelled')).to eq(1)
        expect(get_items_count('cancelling')).to eq(5)

        expect(get_queue_count).to eq(5)
        expect(get_failed_queue_count).to eq(1)

        @analysis_job.reload
        test_stats_for(@analysis_job, {
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

        expect(@analysis_job.deleted?).to eq(true)
      end

      it 'will let all job items complete (message queue depletion) - but it wont transition to :complete!' do
        6.times do
          expect {
            perform_job
          }.to raise_error(RuntimeError, /Failed to update AnalysisJobItem, status: 422/)
        end

        expect(get_items_count).to eq(6)
        expect(get_items_count('cancelled')).to eq(6)
        expect(get_items_count('cancelling')).to eq(0)

        expect(get_queue_count).to eq(0)
        expect(get_failed_queue_count).to eq(6)

        @analysis_job.reload
        test_stats_for(@analysis_job, {
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

        expect(@analysis_job).to be_suspended
        expect(@analysis_job.deleted?).to eq(true)

        mail = ActionMailer::Base.deliveries.last
        expect(mail['subject'].value).not_to include('Completed analysis job')
      end
    end

    describe 'status: "completed"' do
      before do
        reset
        ActionMailer::Base.deliveries.clear

        @analysis_job = create_analysis_job

        6.times do
          perform_job
        end

        status_code, response = destroy_analysis_job(@analysis_job.id)
        expect(status_code).to eq(204)

        @analysis_job.reload

        expect(@analysis_job.deleted?).to eq(true)
      end

      it 'is :completed when deleted' do
        expect(@analysis_job).to be_completed
      end

      it 'has no job items to remove from the message queue' do
        expect(get_queue_count).to eq(0)
        expect(get_failed_queue_count).to eq(0)
      end

      it 'ensures there are no non-completed AnalysisJobsItems statuses' do
        expect(get_items_count).to eq(6)
        expect(get_items_count('successful')).to eq(6)
      end

      it 'correctly updates progress statistics' do
        test_stats_for(@analysis_job, {
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
