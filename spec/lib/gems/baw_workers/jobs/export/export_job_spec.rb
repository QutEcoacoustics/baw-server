# frozen_string_literal: true

describe BawWorkers::Jobs::Export::ExportJob, :clean_by_truncation do
  create_audio_recordings_hierarchy

  # Jobs stay in the queue until a test calls `perform_jobs`.
  pause_all_jobs

  before do
    clear_pending_jobs

    audio_event = create(:audio_event, audio_recording:, creator: writer_user)
    create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user)
  end

  let(:queue_name) { Settings.actions.export.queue }

  let(:export) {
    options = {
      project_capture_method: ['continuous'],
      project_sampling_design: 'simpleRandom',
      contributors: [{ title: 'Alice', path: 'http://www.test' }]
    }

    create(:export, creator: owner_user, project: project, name: 'My Package', options: options)
  }

  context 'when checking basic job behaviour' do
    it 'works on the export queue' do
      expect(BawWorkers::Jobs::Export::ExportJob.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      BawWorkers::Jobs::Export::ExportJob.enqueue(export)

      expect_enqueued_jobs 1, of_class: BawWorkers::Jobs::Export::ExportJob

      clear_pending_jobs
    end

    it 'builds the job id from the export id, so different exports get different job ids' do
      other = create(:export, creator: owner_user, project: project, name: 'Other Package')

      job_class = BawWorkers::Jobs::Export::ExportJob

      expect(job_class.new(export).job_id).to eq("BawWorkers:Jobs:Export:ExportJob:id=#{export.id}")
      expect(job_class.new(other).job_id).not_to eq(job_class.new(export).job_id)
    end
  end

  it 'successfully enqueues and performs the export' do
    BawWorkers::Jobs::Export::ExportJob.enqueue(export)
    perform_jobs(count: 1)

    export.reload
    aggregate_failures do
      expect(export).to be_status_ready
      expect(export.file).to be_attached
      expect(export.file.content_type).to eq('application/zip')
    end
  end

  it 'generates the export on retry when the failed first attempt left it working' do
    Fixtures::FlakyExportJob.perform_later!(export)
    # attempt 1 fails and leaves the export working; attempt 2 is the scheduled retry
    perform_jobs(count: 2, timeout: 15)

    aggregate_failures do
      expect(export.reload).to be_status_ready
      expect(export.file).to be_attached
    end
  end

  it 'skips an export that is already working when the job runs for the first time' do
    export.update!(status: 'working')

    BawWorkers::Jobs::Export::ExportJob.enqueue(export)
    perform_jobs(count: 1)

    aggregate_failures do
      expect(export.reload).to be_status_working
      expect(export.file).not_to be_attached
    end
  end

  it 'generates the export when the job is enqueued again after the first job ended with the export failed' do
    export.update!(options: export.options.merge('emit_project_license' => true))
    project.update!(license: 'x' * 40)

    BawWorkers::Jobs::Export::ExportJob.enqueue(export)
    perform_jobs(count: 1)
    expect(export.reload).to be_status_failed

    project.update!(license: 'CC-BY-4.0')
    BawWorkers::Jobs::Export::ExportJob.enqueue(export)
    perform_jobs(count: 1)

    expect(export.reload).to be_status_ready
  end
end
