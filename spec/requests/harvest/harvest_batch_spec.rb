# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  extend WebServerHelper::ExampleGroup

  describe 'errors' do
    render_error_responses

    it 'cannot create a new harvest in any state' do
      body = {
        harvest: {
          streaming: false,
          status: :uploading
        }
      }

      post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :unprocessable_entity,
        'The request could not be understood: found unpermitted parameter: :status'
      )
    end

    # execute the following specs in order without resetting state between them
    stepwise 'cannot transition into an error state' do
      step 'can be created' do
        create_harvest
        expect(harvest).to be_uploading
      end

      [:new_harvest, :metadata_review, :processing, :review].each do |status|
        step "cannot transition from uploading->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :metadata_extraction' do
        transition_harvest(:metadata_extraction)
        expect_success
        expect(harvest).to be_metadata_extraction
      end

      [:new_harvest, :uploading, :metadata_review, :processing, :review].each do |status|
        step "the client cannot transition from metadata_extraction->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed(status)
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
      end

      step 'can transition to :metadata_review when a client fetches the record' do
        get_harvest
        expect(harvest).to be_metadata_review
      end

      [:new_harvest].each do |status|
        step "cannot transition from metadata_review->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :processing' do
        transition_harvest(:processing)
        expect_success
        expect(harvest).to be_processing
      end

      [:new_harvest, :uploading, :metadata_review, :processing].each do |status|
        step "the client cannot transition from processing->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed(status)
        end
      end

      step 'can transition to :complete when a client fetches the record' do
        get_harvest
        expect(harvest).to be_complete
      end
    end
  end

  describe 'File system permissions' do
    it 'can create a new directories in streaming mode' do
      create_harvest(streaming: false)
      get_harvest
      expect_upload_slot_enabled

      create_remote_directory(connection, '/abc', should_work: true)
    end
  end

  describe 'optimal workflow', :clean_by_truncation do
    expose_app_as_web_server
    pause_all_jobs

    let(:another_site) {
      Common.create_site(owner_user, project, region)
    }

    stepwise 'a single file is uploaded' do
      step 'a streaming harvest can be created' do
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
        @name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'), extension: '.ogg')
        upload_file(connection, Fixtures.audio_file_mono, to: "/#{site.id}/#{@name}")
      end

      step 'we can see a harvest job has been enqueued' do
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
        @names = []
        5.times do |i|
          name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'), ambiguous: true, extension: '.ogg')
          @names << name
          file = generate_audio(name, sine_frequency: 440 * i)
          sub_dir = generate_random_sub_directories
          upload_file(connection, file, to: "/#{sub_dir}#{name}")
        end
      end

      step 'we can see 4 harvest jobs have been enqueued' do
        expect_enqueued_jobs(4, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we delete the enqueued jobs to simulate the webhook not working' do
        clear_pending_jobs
        # also delete two of the harvest items
        HarvestItem.sort(created_at: :desc).limit(2).delete

        expect_enqueued_jobs(0, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        expect(HarvestItem.count).to eq 4
      end

      step 'we can transition to :metadata_extraction' do
        transition_harvest(:metadata_extraction)
        expect(harvest).to be_metadata_extraction
      end

      step 'metadata extraction finds and enqueues any missing files' do
        expect_enqueued_jobs(5, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
        expect(HarvestItem.count).to eq 6
      end

      step 'we perform the jobs' do
        perform_jobs(count: 5)
        expect_jobs_to_be(completed: 6, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'after fetching the harvest transitions itself to metadata_review' do
        get_harvest

        expect(harvest).to be_metadata_review
      end

      step 'we expect some metadata to be gathered (there are validation errors)' do
        aggregate_failures do
          expect(HarvestItem.count).to eq 6
          expect(HarvestItem.all).to all(be_metadata_extracted)
          expect(HarvestItem.first.info.to_h).to match(a_hash_including(
            error: nil,
            validations: []
          ))
          expect(HarvestItem.all.offset(1).map { |h| h.info.to_h }).to all(match(a_hash_including(
            error: nil,
            validations: [
              a_hash_including(
                code: :no_site_id
              ),
              a_hash_including(
                code: :ambiguous_date_time
              )
            ]
          )))
        end
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_uploading

        expect_report_stats(
          count: 6,
          size: @size,
          duration: 70 + (30 * 3),
          metadata_gathered: 6,
          failed: 0
        )
      end

      step 'we add a mapping to fix the validation errors' do
        add_mapping(BawWorkers::Jobs::Harvest::Mapping.new(
          site_id: another_site.id,
          path: '',
          utc_offset: '-04:00',
          recursive: true
        ))
      end

      step 'we can then perform the metadata extraction again' do
        perform_all_jobs_immediately do
          transition_harvest(:metadata_extraction)
        end
      end

      step 'we wait until metadata extraction is complete' do
        10.times do
          logger.info 'Waiting for metadata extraction to complete...'
          sleep 0.5
          get_harvest
          break if harvest.metadata_review
        end

        expect(harvest).to be_metadata_review
      end

      step 'all recordings should have been analyzed again' do
        # 6 recordings, metadata extraction has occurred twice
        expect_jobs_to_be(completed: 12, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'all harvest items should have no validation errors' do
      end
    end
  end
end
