# frozen_string_literal: true

describe 'AnalysisJobMailer views' do
  let(:analysis_job) { create(:analysis_job) }
  let(:expected_url) { Settings.client_routes.analysis_job_url(analysis_job).to_s }

  it 'new job message contains correct body' do
    message = AnalysisJobMailer.new_job_message(analysis_job, nil)

    expect(message.body.decoded).to include('<strong>created a new</strong>', expected_url)
  end

  it 'completed job message contains correct body' do
    message = AnalysisJobMailer.completed_job_message(analysis_job, nil)

    expect(message.body.decoded).to include('<strong>completed</strong>', expected_url)
  end

  it 'retry job message contains correct body' do
    message = AnalysisJobMailer.retry_job_message(analysis_job, nil)

    expect(message.body.decoded).to include('<strong>retried</strong>', expected_url)
  end
end
