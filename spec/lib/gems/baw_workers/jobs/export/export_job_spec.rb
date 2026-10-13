# frozen_string_literal: true

describe BawWorkers::Jobs::Export::ExportJob do
  create_audio_recordings_hierarchy

  # Keeps things in the worker queue, so you can run in the test when you want.
  # Then you queue, then run perform_job from the resque helpers.
  # Then you reload model.
  pause_all_jobs

  before do
    clear_pending_jobs

    audio_event = create(:audio_event, audio_recording:, creator: writer_user)
    create(:tagging, audio_event:, tag: create(:tag_taxonomic_true_species), creator: writer_user)
  end

  let(:queue_name) { Settings.actions.export.queue }

  let(:export) {
    create(:export, creator: owner_user)
  }

  # TODO: With enough on model, won't need stepwise or clean by truncation
  context 'when checking basic job behaviour' do
    it 'works on the export queue' do
      expect(described_class.queue_name).to eq(queue_name)
    end

    it 'can enqueue' do
      described_class.perform_later(export)

      expect_enqueued_jobs 1, of_class: described_class

      clear_pending_jobs
    end
  end

  it 'creates a zip archive and marks the export as ready' do
    # TODO: Perform now runs in thread. Not in the worker environment.
    # So use perform later.
    described_class.perform_now(export)

    export.reload
    expect(export).to be_status_ready
    expect(export.file).to be_attached
    expect(export.file.content_type).to eq('application/zip')
  end
end
