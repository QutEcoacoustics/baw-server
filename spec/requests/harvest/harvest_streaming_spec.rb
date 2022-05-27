# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting streaming files' do
  extend WebServerHelper::ExampleGroup
  include HarvestSpecCommon

  describe 'errors' do
    it 'cannot create a new harvest in any state' do
      body = {
        harvest: {
          streaming: true,
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
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
      end

      [:new_harvest, :scanning, :metadata_extraction, :metadata_review, :processing].each do |status|
        step "cannot transition from uploading->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end
    end
  end

  describe 'File system permissions' do
    it 'cannot create a new directories in streaming mode' do
      create_harvest(streaming: true)
      get_harvest
      expect_upload_slot_enabled
      out = create_remote_directory(connection, '/abc', should_work: false)
      expect(out).to match(/mkdir command failed: Permission denied/)
    end
  end

  describe 'optimal workflow', :clean_by_truncation do
    expose_app_as_web_server
    pause_all_jobs

    stepwise 'a single file is uploaded' do
      step 'a streaming harvest can be created' do
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
        expect(harvest).to be_streaming_harvest
        expect(harvest).not_to be_batch_harvest
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

      step 'we can observe the webhook has fired' do
        wait_for_webhook
      end

      step 'we can see harvest job has been enqueued' do
        expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we can see a harvest item was created' do
        expect(HarvestItem.count).to eq 1
      end

      step 'we can harvest the file' do
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'we can see the harvest item was completed' do
        aggregate_failures do
          expect(HarvestItem.count).to eq 1
          item = HarvestItem.first

          expect(item).to be_completed
          expect(item.info.to_h).to match(a_hash_including(
            error: nil,
            validations: []
          ))

          expect(AudioRecording.count).to eq 1
          expect(AudioRecording.first.original_file_name).to eq @name
        end
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_uploading

        expect_report_stats(
          items_total: 1,
          items_size_bytes: Fixtures.audio_file_mono.size,
          items_duration_seconds: audio_file_mono_duration_seconds,
          items_completed: 1
        )
      end

      step 'we can query audio_recordings for the file based off of the harvest id' do
        recordings = get_audio_recordings_for_harvest

        expect(recordings).to match([
          a_hash_including(
            id: an_instance_of(Integer),
            status: 'ready',
            original_file_name: @name,
            site_id: site.id
          )
        ])
      end
    end

    stepwise 'supports uploading multiple files' do
      # trying to simulate a properly asynchronous execution
      perform_all_jobs_normally

      step 'create a streaming harvest' do
        create_harvest(streaming: true)
      end

      step 'we can upload a file' do
        name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'))
        file = generate_audio(name, sine_frequency: 440)
        @size = file.size
        upload_file(connection, file, to: "/#{site.id}/#{name}")
      end

      step 'we can upload another file' do
        name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 30, '+00:00'))
        file = generate_audio(name, sine_frequency: 880)
        @size += file.size
        upload_file(connection, file, to: "/#{site.id}/#{name}")
      end

      step 'we can upload a badly named file' do
        file = Fixtures.audio_file_mono
        name = file.basename
        @size += file.size
        upload_file(connection, file, to: "/#{site.id}/#{name}")
      end

      step 'we can upload a final file' do
        name = generate_recording_name(Time.new(2020, 1, 1, 0, 1, 0, '+00:00'))
        file = generate_audio(name, sine_frequency: 1760)
        @size += file.size
        upload_file(connection, file, to: "/#{site.id}/#{name}")
      end

      step 'we will wait for harvests jobs to run' do
        # average time to harvest is 3.5 seconds
        wait_for_jobs(timeout: 4 * 3.5)
      end

      step 'we expect 4 harvest items to be created' do
        expect(HarvestItem.count).to eq 4
      end

      step 'we expect 3 audio recordings to be created' do
        expect(AudioRecording.count).to eq 3
      end

      step 'we can see the faulty harvest item has validation errors related to its missing date stamp' do
        failed = HarvestItem.where(status: HarvestItem::STATUS_FAILED).first
        aggregate_failures do
          expect(failed).to be_failed
          expect(failed.info.to_h).to match(a_hash_including(
            error: nil,
            validations: [
              a_hash_including(
                name: :missing_date
              )
            ]
          ))
        end
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_uploading
        expect_report_stats(
          items_total: 4,
          items_size_bytes: @size,
          items_duration_seconds: 70 + (30 * 3),
          items_completed: 3,
          items_failed: 1,
          items_invalid_fixable: 1,
          items_invalid_not_fixable: 0
        )
      end
    end
  end

  describe 'harvest can complete', :clean_by_truncation do
    expose_app_as_web_server
    pause_all_jobs

    stepwise 'complete a harvesting an item even after the harvest is closed' do
      step 'create a harvest' do
        create_harvest(streaming: true)
        expect(harvest).to be_uploading
      end

      step 'upload a file' do
        name = generate_recording_name(Time.new(2020, 1, 1, 0, 0, 0, '+00:00'))
        file = generate_audio(name, sine_frequency: 440)
        @size = file.size
        upload_file(connection, file, to: "/#{site.id}/#{name}")
      end

      step 'complete the harvest' do
        transition_harvest(:complete)
        expect(harvest).to be_complete
      end

      step 'the sftp connection is closed' do
        expect_upload_slot_deleted
      end

      step 'our harvest endpoint removes login details' do
        expect_empty_sftp_login_details
      end

      step 'process the queued harvest item job' do
        perform_jobs(count: 1)
        expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::HarvestJob)
      end

      step 'a new recording is available' do
        expect(AudioRecording.count).to eq 1
        item = HarvestItem.first
        expect(item).to be_completed
      end

      step 'our report has useful statistics' do
        get_harvest
        expect(harvest).to be_complete

        expect_report_stats(
          items_total: 1,
          items_size_bytes: @size,
          items_duration_seconds: 30,
          items_completed: 1
        )
      end
    end
  end
end
