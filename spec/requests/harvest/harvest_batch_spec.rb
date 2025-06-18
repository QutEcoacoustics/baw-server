# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  extend WebServerHelper::ExampleGroup

  describe 'errors', :clean_by_truncation do
    render_error_responses
    pause_all_jobs

    it 'cannot create a new harvest in any state' do
      body = {
        harvest: {
          streaming: false,
          status: :uploading
        }
      }

      post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :unprocessable_content,
        'The request could not be understood: found unpermitted parameter: :status'
      )
    end

    # execute the following specs in order without resetting state between them
    stepwise 'cannot transition into an error state' do
      step 'can be created' do
        create_harvest
        expect(harvest).to be_uploading
      end

      [:new_harvest, :metadata_extraction, :metadata_review, :processing, :review].each do |status|
        step "cannot transition from uploading->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :scanning' do
        transition_harvest(:scanning)
        expect_success
        expect(harvest).to be_scanning
      end

      step 'it will automatically transition from :scanning to :metadata_extraction' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

        harvest.reload
        expect(harvest).to be_metadata_extraction
      end

      [:new_harvest, :uploading, :scanning, :metadata_review, :processing, :review].each do |status|
        step "the client cannot transition from :metadata_extraction->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed
        end
      end

      step 'can transition to :metadata_review when a client fetches the record' do
        get_harvest
        expect(harvest).to be_metadata_review
      end

      step 'can transition back to :metadata_extraction (again)' do
        transition_harvest(:metadata_extraction)
        expect_success
        expect(harvest).to be_metadata_extraction

        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      end

      step 'can transition to :metadata_review when a client fetches the record' do
        get_harvest
        expect(harvest).to be_metadata_review
      end

      [:new_harvest, :scanning].each do |status|
        step "cannot transition from metadata_review->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :processing' do
        transition_harvest(:processing)
        expect_success
        expect(harvest).to be_processing

        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 2, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      end

      [:new_harvest, :uploading, :scanning, :metadata_review, :processing].each do |status|
        step "the client cannot transition from processing->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed
        end
      end

      step 'can transition to :complete when a client fetches the record' do
        get_harvest
        expect(harvest).to be_complete
      end

      step 'we expect an analysis amend job to be enqueued' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::AmendAfterHarvestJob)
        # but no other jobs
        expect_enqueued_jobs(1)
        clear_pending_jobs
      end
    end
  end

  describe 'File system permissions' do
    it 'can create new directories in batch mode' do
      create_harvest(streaming: false)
      get_harvest
      expect_upload_slot_enabled

      create_remote_directory(connection, '/abc', should_work: true)
    end
  end

  describe 'optimal workflow', :clean_by_truncation, :slow, web_server_timeout: 120 do
    expose_app_as_web_server
    pause_all_jobs

    let(:another_site) {
      Creation::Common.create_site(owner_user, project, region:)
    }

    stepwise 'files are uploaded' do
      step 'a batch harvest can be created' do
        create_harvest(streaming: false)
        expect(harvest).to be_uploading
        expect(harvest).not_to be_streaming_harvest
        expect(harvest).to be_batch_harvest
      end

      step 'SFTPGO has an upload slot enabled' do
        expect_upload_slot_enabled
      end

      step 'Our harvest endpoint returns login details' do
        expect_filled_in_sftp_login_details
      end

      step 'Our harvest has pre-made mappings' do
        expect_pre_filled_mappings
      end

      step 'we can upload a file' do
        @names = []

        name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'), extension: '.ogg')
        @names << name

        @size = Fixtures.audio_file_mono.size
        upload_file(connection, Fixtures.audio_file_mono, to: "/#{site.unique_safe_name}/#{name}")
      end

      step 'we can see a harvest job has been enqueued' do
        wait_for_webhook
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we can see a harvest item was created' do
        expect(HarvestItem.count).to eq 1
      end

      step 'we can get metadata for the file' do
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we can upload another few files' do
        5.times do |i|
          name = generate_recording_name(Time.new(2020, 1, 1, i, 0, 0, '+00:00'), ambiguous: true, extension: '.ogg')
          @names << name
          file = generate_audio(name, sine_frequency: 440 * i)
          @size += file.size
          sub_dir = generate_random_sub_directories
          upload_file(connection, file, to: "/#{sub_dir}#{name}")
        end
      end

      step 'we can see 5 harvest jobs have been enqueued' do
        wait_for_webhook(goal: 6)
        expect_enqueued_jobs(5, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we delete the enqueued jobs to simulate the webhook not working' do
        clear_pending_jobs
        # clear_pending_jobs also clears the queue and all statuses that were in the queue
        expect_jobs_to_be(completed: 0, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

        # also delete two of the harvest items
        HarvestItem.order(created_at: :desc).limit(2).delete_all

        expect_enqueued_jobs(0, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        expect(HarvestItem.count).to eq 4
      end

      step 'we can transition to :scanning' do
        transition_harvest(:scanning)
        expect_success
        expect(harvest).to be_scanning
      end

      step 'scanning enqueues a scan job' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
      end

      step 'scanning finds and enqueues any missing files' do
        expect_enqueued_jobs(5, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        expect(HarvestItem.count).to eq 6
      end

      step 'the scanning job transitions to :metadata_extraction' do
        get_harvest
        expect(harvest).to be_metadata_extraction
      end

      step 'we perform the jobs' do
        perform_jobs(count: 5)
        expect_jobs_to_be(completed: 5, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'after fetching the harvest transitions itself to metadata_review' do
        get_harvest

        expect(harvest).to be_metadata_review
      end

      step 'we expect some metadata to be gathered (there are validation errors)' do
        aggregate_failures do
          expect(HarvestItem.count).to eq 6
          expect(HarvestItem.all).to all(be_metadata_gathered)
          expect(HarvestItem.first.info.to_h).to match(a_hash_including(
            error: nil,
            validations: []
          ))

          query = HarvestItem.order(:id).offset(1).map { |h| h.info.to_h }
          expect(query).to all(match(a_hash_including(
            error: nil,
            validations: [
              a_hash_including(
                name: :ambiguous_date_time
              ),
              a_hash_including(
                name: :no_site_id
              )

            ]
          )))
        end
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_metadata_review

        expect_report_stats(
          items_total: 6,
          items_size_bytes: @size,
          items_duration_seconds: 70 + (30 * 5),
          items_metadata_gathered: 6,
          items_invalid_fixable: 5,
          items_invalid_not_fixable: 0
        )
      end

      step 'we add a mapping to fix the validation errors' do
        add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
          site_id: another_site.id,
          path: '',
          utc_offset: '-04:00',
          recursive: true
        ))

        expect_success

        expect(harvest.mappings).to match(a_collection_containing_exactly(
          a_hash_including(
            site_id: site.id,
            path: site.unique_safe_name,
            utc_offset: nil,
            recursive: true
          ),
          a_hash_including(
            site_id: another_site.id,
            path: '',
            utc_offset: '-04:00',
            recursive: true
          )
        ))
      end

      step 'we can then perform the metadata extraction again' do
        # the previous harvest jobs statuses will deleted when they are reenqueued which
        # messes up our accounting and results in the perform_jobs in the next step
        # timing out
        BawWorkers::ResqueApi.statuses_clear

        transition_harvest(:metadata_extraction)
        expect_success
      end

      step 'the reenqueue job runs (for :metadata_extraction)' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      end

      step 'we perform the harvest jobs' do
        perform_jobs(count: 6)
      end

      step 'we wait until metadata extraction is complete' do
        20.times do |i|
          logger.info 'Waiting for metadata extraction to complete...', count: i
          sleep 0.5
          get_harvest
          break if harvest.metadata_review?
        end

        expect(harvest).to be_metadata_review
      end

      step 'all recordings should have been analyzed again' do
        # 6 recordings, metadata extraction has occurred twice
        # but the statuses are re-used so we see 6 instead of 12
        expect_jobs_to_be(completed: 6, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'all harvest items should have no validation errors' do
        aggregate_failures do
          expect(HarvestItem.count).to eq 6
          all = HarvestItem.all
          expect(all).to all(be_metadata_gathered)

          all.each do |item|
            expect(item.info.to_h).to match(a_hash_including(
              error: nil,
              validations: []
            ))
          end
        end
      end

      step 'we can then transition to :processing' do
        transition_harvest(:processing)
        expect_success

        expect(harvest).to be_processing
      end

      step 'the reenqueue job runs (for :processing)' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 2, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      end

      step 'we expect 6 harvest jobs to be enqueued' do
        expect_enqueued_jobs(6, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we can process the jobs' do
        perform_jobs(count: 6)
        expect_jobs_to_be(completed: 12, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we wait until processing is complete' do
        10.times do
          logger.info 'Waiting for processing to complete...'
          sleep 0.1
          get_harvest
          break if harvest.complete?
        end

        expect(harvest).to be_complete
      end

      step 'we can see the harvest items are completed' do
        aggregate_failures do
          expect(HarvestItem.count).to eq 6
          all = HarvestItem.all
          expect(all).to all(be_completed)
          all.each do |item|
            expect(item.info.to_h).to match(a_hash_including(
              error: nil,
              validations: []
            ))
          end

          expect(AudioRecording.count).to eq 6
          all = AudioRecording.all
          expect(all).to all(be_ready)
          expect(all.map(&:original_file_name)).to match_array @names
          expect(AudioRecording.group(:recorded_utc_offset).count).to eq({
            '+0000' => 1,
            '-04:00' => 5
          })
          expect(AudioRecording.group(:site_id).count).to eq({
            another_site.id => 5,
            site.id => 1
          })
        end
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_complete

        expect_report_stats(
          items_total: 6,
          items_size_bytes: @size,
          items_duration_seconds: 70 + (30 * 5),
          items_completed: 6
        )
      end

      step 'we can query audio_recordings for the file based off of the harvest id' do
        recordings = get_audio_recordings_for_harvest

        expect(recordings.size).to eq 6
      end

      step 'we expect an analysis amend job to be enqueued' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::AmendAfterHarvestJob)
        # but no other jobs
        expect_enqueued_jobs(1)
        clear_pending_jobs
      end
    end

    context 'when files are mutated after initial upload' do
      before do
        create_harvest(streaming: false)
        expect(harvest).to be_uploading
        expect(harvest).to be_batch_harvest

        @name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'), extension: '.ogg')
        file = generate_audio(@name, sine_frequency: 440)

        upload_file(connection, file, to: "/#{site.unique_safe_name}/#{@name}")

        wait_for_webhook
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

        expect(HarvestItem.count).to eq 1
      end

      stepwise 'deleting a file' do
        step 'we can get metadata for the file' do
          perform_jobs(count: 1)
          expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        end

        step 'we can delete the file we just uploaded' do
          delete_remote_file(connection, "/#{site.unique_safe_name}/#{@name}")
        end

        step 'we expect our webhook was fired' do
          wait_for_webhook(goal: 2)
        end

        step 'we can see the harvest item was deleted' do
          expect(HarvestItem.count).to eq 0
        end
      end

      stepwise 'deleting a file (before the job is dequeued)' do
        step 'we can delete the file we just uploaded' do
          delete_remote_file(connection, "/#{site.unique_safe_name}/#{@name}")
        end

        step 'we expect our webhook was fired' do
          wait_for_webhook(goal: 2)
        end

        step 'we can see the harvest item was deleted' do
          expect(HarvestItem.count).to eq 0
        end

        step 'then the metadata job could be dequeued' do
          statuses = perform_jobs(count: 1)
          expect_jobs_to_be(completed: 0, failed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

          expect(statuses.length).to eq 1
          status = statuses.first

          expect(status).to be_failed
          expect(status.messages).to contain_exactly(/Harvest item \d+ not found/,
            /Couldn't find HarvestItem with 'id'=\d+/)
        end

        step 'we can see the harvest item is still deleted' do
          expect(HarvestItem.count).to eq 0
        end
      end

      stepwise 'renaming a file works' do
        step 'make a new folder' do
          create_remote_directory(connection, '/banana')
        end

        step 'rename the file' do
          rename_remote_file(connection, from: "/#{site.unique_safe_name}/#{@name}", to: "/banana/#{@name}")
        end

        step 'we expect our webhook was fired' do
          wait_for_webhook(goal: 2)
        end

        step 'we can see the harvest item was renamed' do
          item = HarvestItem.first
          expect(item.path).to eq "harvest_#{harvest.id}/banana/#{@name}"
        end

        step 'we can see two enqueued jobs - one new and one old' do
          # our de-duplication mechanism is at work! *chefs kiss* 👌
          expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        end

        step 'we can run the jobs and get metadata for the file' do
          perform_jobs(count: 1)
          expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        end

        step 'we can see the harvest item was successfully processed' do
          item = HarvestItem.first
          expect(item.path).to eq "harvest_#{harvest.id}/banana/#{@name}"
          expect(item).to be_metadata_gathered
          expect(item.info.to_h).to match(a_hash_including(
            error: nil,
            validations: [
              a_hash_including(
                name: :no_site_id
              )
            ]
          ))
        end
      end
    end

    context 'with non-unique site names' do
      let!(:site1) { Creation::Common.create_site(owner_user, project, name: 'site') }
      let!(:site2) { Creation::Common.create_site(owner_user, project, name: 'site') }
      # testing uniqueness detection applies to the safe name!
      let!(:site3) { Creation::Common.create_site(owner_user, project, name: 'ban!ana') }
      let!(:site4) { Creation::Common.create_site(owner_user, project, name: 'ban ana') }

      it 'has unique directories and mappings' do
        create_harvest
        expect_success

        get_harvest

        expect(api_data).to match(a_hash_including({
          mappings: contain_exactly(
            {
              path: site.unique_safe_name,
              site_id: site.id,
              utc_offset: nil,
              recursive: true
            },
            {
              path: site1.unique_safe_name,
              site_id: site1.id,
              utc_offset: nil,
              recursive: true
            },
            {
              path: site2.unique_safe_name,
              site_id: site2.id,
              utc_offset: nil,
              recursive: true
            },
            {
              path: site3.unique_safe_name,
              site_id: site3.id,
              utc_offset: nil,
              recursive: true
            },
            {
              path: site4.unique_safe_name,
              site_id: site4.id,
              utc_offset: nil,
              recursive: true
            }
          )
        }))

        [
          site.unique_safe_name,
          site1.unique_safe_name,
          site2.unique_safe_name,
          site3.unique_safe_name,
          site4.unique_safe_name
        ].each do |name|
          expect(harvest.upload_directory / name).to be_exist
        end
      end
    end
  end

  describe 'unhandled errors in the harvest job', :clean_by_truncation, :slow, web_server_timeout: 60 do
    expose_app_as_web_server
    pause_all_jobs

    stepwise 'can transition to metadata_review if an error occurred in :metadata_extraction' do
      step 'create a harvest' do
        create_harvest(streaming: false)
        expect(harvest).to be_uploading
        expect(harvest).to be_batch_harvest
      end

      step 'generate and upload a file' do
        name = generate_recording_name(Time.new(2022, 6, 22, 15, 56, 0, '+10:00'))
        file = generate_audio(name, sine_frequency: 440)

        upload_file(connection, file, to: "/#{site.unique_safe_name}/#{name}")
      end

      step 'wait for webhook and process the file' do
        wait_for_webhook
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        perform_jobs(count: 1)
      end

      step 'we can see the harvest item was successfully processed' do
        expect(HarvestItem.count).to eq 1
        @item = HarvestItem.first

        expect(@item).to be_metadata_gathered
      end

      step 'transition to scanning' do
        transition_harvest(:scanning)
        expect_success
        expect(harvest).to be_scanning
      end

      step 'finish the scan' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
      end

      step 'fake an error' do
        # fake an error
        @item.status = HarvestItem::STATUS_ERRORED
        @item.save!

        expect(@item).to be_metadata_gathered_or_unsuccessful
      end

      step 'check we are in the :metadata_gathering state' do
        harvest.reload
        expect(harvest).to be_metadata_extraction
      end

      step 'can transition from :metadata_gathering to :metadata_review' do
        get_harvest

        expect(harvest).to be_metadata_extraction_complete
        expect(harvest).to be_metadata_review
      end

      step 'can transition from :metadata_review to :processing' do
        transition_harvest(:processing)
        expect_success

        expect(harvest).to be_processing
      end

      step 'the reenqueue job runs (for :processing)' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ReenqueueJob)
      end

      step 'process files' do
        perform_jobs(count: 1)
      end

      step 'fake an error' do
        @item.reload
        # fake an error
        @item.status = HarvestItem::STATUS_ERRORED
        @item.save!

        expect(@item).to be_terminal_status
      end

      step 'can transition from :processing to :complete' do
        get_harvest

        expect(harvest).to be_processing_complete
        expect(harvest).to be_complete
      end

      step 'we expect an analysis amend job to be enqueued' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Analysis::AmendAfterHarvestJob)
        # but no other jobbs
        expect_enqueued_jobs(1)
        clear_pending_jobs
      end
    end
  end

  describe 'race conditions', :clean_by_truncation, :slow, web_server_timeout: 60 do
    expose_app_as_web_server

    # very intentionally seeking asynchronous behaviour in this job
    #pause_all_jobs

    # Ok; we're trying to replicate a production bug here so we're going to
    # do some weird timing things.
    # In production it seems that in the time taken to re-enqueue all the jobs
    # some jobs already ran.
    #
    # - transaction opens
    # - each harvest job is enqueued, and each harvest_item to :new (transaction not yet committed)
    # - a harvest job runs setting harvest_item to :metadata_gathered
    # - the transaction is committed, overwriting the fresh :metadata_gathered status with :new
    # - the harvest stalls waiting for all items to be :metadata_gathered

    let(:duplicates) { 10 }

    let(:slow_enqueue) {
      Class.new(BawWorkers::Jobs::Harvest::HarvestJob) do
        def self.enqueue(...)
          result = super
          # Sleep after enqueue so job is running in the background, but our overall enqueue process is slowed down.
          # This should be roughly to enqueuing many files
          logger.warn('Intentional slow enqueue!!!!!!!!')
          sleep(1)
          result
        end
      end
    }

    # For setup, create some real files, but also a large number of dummy items
    # - enough to trigger some race conditions during enqueuing
    before do
      stub_const('BawWorkers::Jobs::Harvest::HarvestJob', slow_enqueue)

      create_harvest(streaming: false)
      expect(harvest).to be_uploading
      expect(harvest).to be_batch_harvest

      3.times do |i|
        name = generate_recording_name(Time.new(2020, 1, i + 1, 0, 0, 0, '+00:00'), extension: '.ogg')
        file = generate_audio(name, sine_frequency: 440 + (i * 10), duration: 1.0)

        upload_file(connection, file, to: "/#{site.unique_safe_name}/#{name}")
      end
      wait_for_webhook(goal: 3)
      expect(HarvestItem.count).to eq 3

      # this is not guaranteed to have waited for jobs to finish, adjust timer as needed
      wait_for_jobs(timeout: 15)
      expect_jobs_to_be(completed: 3, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

      # now simulate a very large harvest by creating many harvest items that
      # are just duplicates of one of the other harvest items
      # Note: duplicate has an intentional fault to speed the test suite process
      duplicate_rows_but_with_nonexistent_path

      expect(HarvestItem.count).to eq(duplicates + 3)

      transition_harvest(:scanning)
      expect_success
      expect(harvest).to be_scanning

      wait_for_metadata_extraction_to_complete

      expect(harvest).to be_metadata_extraction_complete
      expect(harvest).to be_metadata_review
    end

    it 'handles larges batches of jobs correctly and does not suffer from a race condition' do
      transition_harvest(:metadata_extraction)
      expect_success

      wait_for_metadata_extraction_to_complete(timeout: 20)

      statuses = HarvestItem.pick_hash(HarvestItem.counts_by_status_arel)

      harvest.reload

      aggregate_failures do
        expect(harvest).to be_metadata_review

        # before this bug was fixed, some items would remain locked to :new
        expect(statuses).to match(a_hash_including({
          HarvestItem::STATUS_NEW => 0,
          HarvestItem::STATUS_METADATA_GATHERED => 3,
          HarvestItem::STATUS_FAILED => duplicates
        }))
      end
    end

    def wait_for_metadata_extraction_to_complete(timeout: 10)
      (timeout * 2).times do |i|
        sleep 0.5
        get_harvest
        logger.info 'Waiting for metadata extraction to complete...', count: i, **api_data[:report]
        break if harvest.metadata_review?
      end
    end

    def duplicate_rows_but_with_nonexistent_path
      columns = (HarvestItem.column_names - ['id']).join(', ')
      columns_without_path = (HarvestItem.column_names - ['id', 'path']).join(', ')
      duplicate_rows_query = <<~SQL.squish
        INSERT INTO harvest_items (#{columns})
        (
          SELECT  path || series.index, #{columns_without_path}
          FROM  (
            SELECT #{columns} FROM harvest_items ORDER BY id DESC LIMIT 1
          ) AS t
          CROSS JOIN LATERAL generate_series(1,#{duplicates}) series(index)
        )
      SQL
      ActiveRecord::Base.connection.execute(duplicate_rows_query)
    end
  end
end
