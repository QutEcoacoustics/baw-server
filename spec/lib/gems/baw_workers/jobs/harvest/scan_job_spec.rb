# frozen_string_literal: true

# our jobs need access to the database from different connections
# thus we can't use our normal transaction cleaning method
describe BawWorkers::Jobs::Harvest::ScanJob, :clean_by_truncation do
  include_context 'shared_test_helpers'

  prepare_users
  prepare_project
  prepare_region
  prepare_site

  pause_all_jobs

  let(:queue_name) { Settings.actions.harvest_scan.queue }

  context 'when checking basic job behaviour' do
    it 'works on the harvest queue' do
      expect(BawWorkers::Jobs::Harvest::ScanJob.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      harvest = create(:harvest)
      BawWorkers::Jobs::Harvest::ScanJob.perform_later!(harvest.id)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      clear_pending_jobs
    end

    it 'has a sensible name' do
      harvest = create(:harvest)

      job = BawWorkers::Jobs::Harvest::ScanJob.new(harvest.id)

      expected = "ScanForHarvest:#{harvest.id}"
      expect(job.name).to eq(expected)
    end

    it 'does not enqueue the same payload into the same queue more than once' do
      expect_enqueued_jobs(0)

      job = BawWorkers::Jobs::Harvest::ScanJob.perform_later!(1)
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
      expect(job.job_id).not_to be_nil

      job2 = BawWorkers::Jobs::Harvest::ScanJob.new(1)
      expect(job2.enqueue).to be false

      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
      expect(job2.job_id).to eq job.job_id
      expect(job2.unique?).to be false

      clear_pending_jobs
    end
  end

  context 'when scanning' do
    prepare_harvest

    # we'll have left over harvest jobs at the end of the test which we do not want to process
    # (they are tested elsewhere)
    ignore_pending_jobs

    before do
      clear_original_audio
      clear_harvester_to_do
      BawWorkers::Config.upload_communicator.delete_all_users
    end

    stepwise 'scanning job workflow' do
      step 'open upload' do
        harvest.open_upload!
      end

      step 'check updater_id is as expected' do
        expect(harvest.updater_id).to be_nil
      end

      step 'create some files' do
        [
          'test_file_1.wav',
          'test_file_4.wav',
          'a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/test_file_2.wav',
          'a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/test_file_3.wav',
          'a/.DS_STORE',
          'System Volume Information/file.txt',
          '20220317_61/244/159/System Volume Information/WPSettings.dat',
          '.hidden/file.txt',
          'a/.bash_profile'
        ].each_with_index do |path, i|
          file_path = harvest.upload_directory / path
          FileUtils.mkdir_p(file_path.dirname)

          # need to write a non-empty file to get past the empty file check in the harvest jobs
          if path.ends_with?('.wav')
            generate_audio(file_path.basename, directory: file_path.dirname, sine_frequency: 110 * i)
          else
            FileUtils.touch(file_path)
          end
        end
      end

      step 'enqueue some jobs already to test the deduplication mechanism' do
        BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
          harvest,
          "#{harvest.upload_directory_name}/test_file_4.wav",
          should_harvest: false
        )
        BawWorkers::Jobs::Harvest::HarvestJob.enqueue_file(
          harvest,
          "#{harvest.upload_directory_name}/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/test_file_3.wav",
          should_harvest: false
        )
        expect_enqueued_jobs(2, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        expect(HarvestItem.count).to eq 2
      end

      step 'perform those two jobs' do
        perform_jobs(count: 2)
        expect_jobs_to_be completed: 2, of_class: BawWorkers::Jobs::Harvest::HarvestJob
      end

      step 'expect both jobs are marked as failed' do
        expect(HarvestItem.count).to eq 2
        expect(HarvestItem.all).to all(be_metadata_gathered)
      end

      step 'close the upload, transition to the scanning state' do
        harvest.scan!
        expect(harvest).to be_scanning
      end

      step 'perform the scan job' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

        perform_jobs_immediately(count: 1)
        wait_for_jobs

        expect_jobs_to_be completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob
      end

      step 'the scan job should have transitioned the harvest to metadata extraction' do
        harvest.reload

        expect(harvest).to be_metadata_extraction
      end

      step 'the scan job should have enqueued the 2 missing harvest jobs, but not the jobs already analyzed' do
        # two files were picked up by the scan and are enqueued for harvesting.
        # Two however were already completed and should not be repeated
        aggregate_failures do
          expect_enqueued_jobs(2, of_class: BawWorkers::Jobs::Harvest::HarvestJob)

          expect(HarvestItem.count).to eq 4
          all = HarvestItem.all.order(path: :asc)
          expect(all.map(&:path)).to eq [
            "harvest_#{harvest.id}/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/test_file_2.wav",
            "harvest_#{harvest.id}/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/test_file_3.wav",
            "harvest_#{harvest.id}/test_file_1.wav",
            "harvest_#{harvest.id}/test_file_4.wav"
          ]

          expect(all.map(&:status)).to eq [
            HarvestItem::STATUS_NEW.to_s,
            HarvestItem::STATUS_METADATA_GATHERED.to_s,
            HarvestItem::STATUS_NEW.to_s,
            HarvestItem::STATUS_METADATA_GATHERED.to_s
          ]
        end
      end

      step 'check updater_id was updated expected' do
        expect(harvest.updater_id).to eq(User.harvester_user.id)
      end
    end

    it 'will not transition the harvest if the harvest is a streaming harvest' do
      harvest.streaming = true
      harvest.open_upload!
      harvest.save!

      BawWorkers::Jobs::Harvest::ScanJob.scan(harvest)
      perform_jobs(count: 1)

      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      harvest.reload

      expect(harvest).to be_uploading
    end

    it 'will transition the harvest even if the harvest was still in :uploading when the job started' do
      harvest.open_upload!
      harvest.save!

      expect(harvest).to be_uploading

      # https://github.com/QutEcoacoustics/baw-server/issues/613
      # the bug is:
      # 1. transition to scan
      # 2. enqueue job
      # 3. job is started
      # 4. model is saved
      # 5. job finishes and stale model is in an invalid state

      waiter = introduce_delay(job_class: BawWorkers::Jobs::Harvest::ScanJob, method: :scan_for_files, delay: 0.5) {
        # 4. model is saved
        harvest.save!
      }

      # 1. transition to scan
      harvest.scan
      # 2. enqueue job
      BawWorkers::Jobs::Harvest::ScanJob.scan(harvest)

      # 3. job is started
      perform_jobs_immediately(count: 1)
      waiter.call
      wait_for_jobs

      # 5. job finishes, but no longer fails because bug fix

      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      harvest.reload

      expect(harvest).to be_metadata_extraction
    end

    it 'if a harvest is closed while the scan job is running it will not error' do
      harvest.open_upload!
      harvest.save!

      expect(harvest).to be_uploading

      # https://github.com/QutEcoacoustics/baw-server/issues/615
      # the bug is:
      # 1. transition to scan (model saved)
      # 2. enqueue job
      # 3. job is started
      # 4. harvest is cancelled during job run
      # 5. job finishes and stale model is in an invalid state and tries to transition to extract when it can't

      waiter = introduce_delay(job_class: BawWorkers::Jobs::Harvest::ScanJob, method: :scan_for_files, delay: 0.5) {
        # 4. harvest is cancelled
        harvest.abort!
      }

      # 1. transition to scan
      harvest.scan!
      # 2. job in enqueued
      expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      # 3. job is started
      perform_jobs_immediately(count: 1)
      waiter.call
      wait_for_jobs

      # 5. job finishes, but no longer fails because bug fix

      expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)

      harvest.reload

      expect(harvest).to be_complete
    end
  end
end
