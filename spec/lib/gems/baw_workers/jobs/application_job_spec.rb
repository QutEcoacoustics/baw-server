describe BawWorkers::Jobs::ApplicationJob, :clean_by_truncation do
  it 'reuses ssh connections' do
    debugger
    Fixtures::SshJob.perform_later
    Fixtures::SshJob.perform_later

    wait_for_jobs_to_finish
    debugger
  end
end
