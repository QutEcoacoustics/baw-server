# frozen_string_literal: true

describe BawWorkers::Jobs::Demo::Job do
  pause_all_jobs

  subject!(:job) do
    payload = BawWorkers::Jobs::Demo::Payload.new(parameter: 'abc')
    BawWorkers::Jobs::Demo::Job.perform_later!(payload)
  end

  it 'basically works' do
    perform_jobs(count: 1)
    job.refresh_status!

    expect(job.status).to be_completed
    expect(job.status.messages).to include('abc')
  end
end
