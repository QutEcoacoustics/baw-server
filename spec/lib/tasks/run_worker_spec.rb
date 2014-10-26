require 'spec_helper'
require 'fakeredis'

describe 'baw:worker:setup' do
  include_context 'rake_tests'
  include_context 'rspect_output_files'

  context 'rake task' do

    before(:each) do
      #File.truncate(worker_log_file, 0) if File.exists?(worker_log_file)
    end

    it 'runs the setup task for bg worker' do

      store_pid_file = BawWorkers::Settings.resque.background_pid_file
      BawWorkers::Settings.resque['background_pid_file'] = './tmp/resque_worker.pid'

      run_rake_task(rake_task_name, default_settings_file)

      expect(program_stdout_content).to include('baw-workers/lib/settings/settings.default.yml loaded.')
      expect(program_stdout_content).to include('===> BawWorkers::Settings namespace set to settings.')

      expect(worker_log_content).to include('Resque worker will poll queues example.')
      expect(worker_log_content).to include('Logging at level 1.')
      expect(worker_log_content).to include('Resque worker will poll every 5 seconds.')
      expect(worker_log_content).to include('Resque worker will run in background with pid file ./tmp/resque_worker.pid.')

      BawWorkers::Settings.resque['background_pid_file'] = store_pid_file
    end

    it 'runs the setup task for fg worker' do

      store_pid_file = BawWorkers::Settings.resque.background_pid_file
      BawWorkers::Settings.resque['background_pid_file'] = nil

      run_rake_task(rake_task_name, default_settings_file)

      expect(program_stdout_content).to include('baw-workers/lib/settings/settings.default.yml loaded.')
      expect(program_stdout_content).to include('===> BawWorkers::Settings namespace set to settings.')

      expect(worker_log_content).to include('Resque worker will poll queues example.')
      expect(worker_log_content).to include('Logging at level 1.')
      expect(worker_log_content).to include('Resque worker will run in foreground.')
      expect(worker_log_content).to include('Resque worker will poll every 5 seconds.')

      BawWorkers::Settings.resque['background_pid_file'] = store_pid_file
    end
  end
end
