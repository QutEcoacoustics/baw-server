require 'spec_helper'
require 'fakeredis'

describe 'baw_workers:setup_worker' do
  include_context 'rake_tests'
  include_context 'rspect_output_files'

  context 'rake task' do

    it 'runs the setup task for bg worker' do

      store_pid_file = BawWorkers::Settings.resque.background_pid_file
      BawWorkers::Settings.resque['background_pid_file'] = './tmp/resque_worker.pid'

      run_rake_task(rake_task_name, default_settings_file)

      #expect(program_stdout_content).to include("===> Using settings file #{default_settings_file}")
      expect(program_stdout_content).to include('===> Polling queues example.')
      expect(program_stdout_content).to include('===> Logging to ./tmp/program_stdout.log at level 1.')
      expect(program_stdout_content).to include('===> Polling every 5 seconds')
      expect(program_stdout_content).to include('===> Running in background with pid file ./tmp/resque_worker.pid.')

      BawWorkers::Settings.resque['background_pid_file'] = store_pid_file
    end

    it 'runs the setup task for fg worker' do

      store_pid_file = BawWorkers::Settings.resque.background_pid_file
      BawWorkers::Settings.resque['background_pid_file'] = nil

      run_rake_task(rake_task_name, default_settings_file)

      #expect(program_stdout_content).to include("===> Using settings file #{default_settings_file}")
      expect(program_stdout_content).to include('===> Polling queues example.')
      expect(program_stdout_content).to include('===> Logging to ./tmp/program_stdout.log at level 1.')
      expect(program_stdout_content).to include('===> Polling every 5 seconds')
      expect(program_stdout_content).to include('===> Running in foreground.')

      BawWorkers::Settings.resque['background_pid_file'] = store_pid_file
    end
  end
end
