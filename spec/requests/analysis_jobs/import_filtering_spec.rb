# frozen_string_literal: true

require_relative 'analysis_jobs_context'

describe 'AnalysisJobs' do
  include_context 'with analysis jobs context'

  it 'persists script import filtering settings on create' do
    create_job(
      scripts: [{
        script_id: script_one.id,
        event_import_minimum_score: 0.5,
        event_import_include_top: 10,
        event_import_include_top_per: 3600
      }]
    )

    analysis_jobs_script = current_job.analysis_jobs_scripts.find_by!(script_id: script_one.id)

    expect(analysis_jobs_script.event_import_minimum_score.to_f).to eq(0.5)
    expect(analysis_jobs_script.event_import_include_top).to eq(10)
    expect(analysis_jobs_script.event_import_include_top_per).to eq(3600)
  end
end
