# frozen_string_literal: true

RSpec.shared_context 'with route set context' do
  # this should include an audio recording that's not part of the following job
  create_audio_recordings_hierarchy

  create_analysis_jobs_matrix(scripts_count: 2, audio_recordings_count: 2)

  # out laying this so we have
  # 1. 4 items assigned to two recordings
  # 2. 1 recordings with items, each of which has results
  # 3. 1 recording with items, none of which have results

  let(:analysis_job_id) { analysis_jobs_matrix[:analysis_jobs].first.id }
  let(:recording_one) { analysis_jobs_matrix[:audio_recordings].first }
  let(:recording_two) { analysis_jobs_matrix[:audio_recordings].second }
  let(:script_one) { analysis_jobs_matrix[:scripts].first }
  let(:script_two) { analysis_jobs_matrix[:scripts].second }
  let(:item_one) {
    analysis_jobs_matrix[:analysis_jobs_items]
      .filter { |item| item.audio_recording_id == recording_one.id }
      .first
  }
  let(:item_two) {
    analysis_jobs_matrix[:analysis_jobs_items]
      .filter { |item| item.audio_recording_id == recording_one.id }
      .second
  }

  let(:year) { recording_one.recorded_date.strftime('%Y') }
  let(:month) { recording_one.recorded_date.strftime('%Y-%m') }

  def item_ids_for(recording = nil, script = nil)
    analysis_jobs_matrix[:analysis_jobs_items]
      .filter { |item|
        recording_match = (recording.nil? ? true : item.audio_recording_id == recording.id)
        script_match = (script.nil? ? true : item.script_id == script.id)
        recording_match && script_match
      }
      .map(&:id)
  end

  before do
    link_analysis_result_file(item_one, Pathname('Test1/Test2/tiles.sqlite3'), target: Fixtures.sqlite_fixture)
    create_analysis_result_directory(item_one, Pathname('empty_dir'))
    link_analysis_result_file(item_one, Pathname('zip/compressed.zip'), target: Fixtures.zip_fixture)
    create_analysis_result_file(item_one, Pathname('.hidden'), content: 'test content')
    create_analysis_result_file(item_one, Pathname('test.log'), content: 'test content')

    # trying to ensure one aji has no results, the 1st and 3rd are for the same recording
    create_analysis_result_file(item_two, Pathname('Test1/blog'), content: 'eat, sleep, code, repeat')

    link_analysis_result_file(item_two, Pathname('tiles-analysis/tiles.sqlite3'), target: Fixtures.sqlite_fixture)

    expect(item_one.audio_recording_id).to eq item_two.audio_recording_id
  end

  after do
    clear_analysis_cache
  end
end
