# frozen_string_literal: true

describe BawWorkers::Jobs::Analysis::ImportResultsJob do
  create_audio_recordings_hierarchy

  create_analysis_jobs_matrix(
    analysis_jobs_count: 1,
    scripts_count: 1,
    audio_recordings_count: 1
  )

  let(:analysis_jobs_item) { analysis_jobs_matrix[:analysis_jobs_items].first }

  before do
    create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example.csv'), content:
    <<~CSV
      audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
      #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
    CSV
    )
  end

  it 'fails unless the item result is success' do
    analysis_jobs_item.result_failed!

    BawWorkers::Jobs::Analysis::ImportResultsJob.perform_now(analysis_jobs_item.id)

    status = expect_performed_jobs(
      1,
      of_class: BawWorkers::Jobs::Analysis::ImportResultsJob
    ).first

    expect(status).to be_failed
    expect(status.messages).to include('Item is not ready to import, status is `failed`')
  end

  it 'imports the results' do
    analysis_jobs_item.result_success!

    BawWorkers::Jobs::Analysis::ImportResultsJob.perform_now(analysis_jobs_item.id)

    status = expect_performed_jobs(
      1,
      of_class: BawWorkers::Jobs::Analysis::ImportResultsJob
    ).first

    expect(status).to be_completed
    expect(analysis_jobs_item.reload.import_success).to be true

    job = analysis_jobs_matrix[:analysis_jobs].first
    item = analysis_jobs_matrix[:analysis_jobs_items].first
    import = job.audio_event_imports.first
    events = AudioEvent.by_import(import.id)
    expect(events.count).to eq(1)

    expect(events).to all(have_attributes(
      # NOTE: audio_recording_id in csv is ignored
      audio_recording_id: item.audio_recording_id,
      creator_id: job.creator_id
    ))
  end

  it 'sets the error on failure' do
    analysis_jobs_item.result_success!
    create_analysis_result_file(analysis_jobs_item, Pathname('sub_folder/generic_example.csv'), content:
    <<~CSV
      audio_recording_id          ,start_time_seconds_MISSPELT,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
      #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
    CSV
    )

    BawWorkers::Jobs::Analysis::ImportResultsJob.perform_now(analysis_jobs_item.id)

    status = expect_performed_jobs(
      1,
      of_class: BawWorkers::Jobs::Analysis::ImportResultsJob
    ).first

    expect(status).to be_failed
    expect(analysis_jobs_item.reload.import_success).to be false
    message = "Failure importing `sub_folder/generic_example.csv`, validation failed: 'start_time_seconds is missing'"
    expect(analysis_jobs_item.error).to include(message)
    expect(status.messages).to include(message)
  end
end
