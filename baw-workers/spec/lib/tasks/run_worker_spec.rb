require 'spec_helper'

describe 'rake tasks' do
  include_context 'shared_test_helpers'

  context 'rake task' do

    it 'runs the setup task for bg worker' do
      # simulate running a resque worker
      reset_settings
      BawWorkers::Config.run(settings_file: RSpec.configuration.default_settings_path, redis: true, resque_worker: true)

      expect(worker_log_content).to match(/"test":true,"file":"[^"]+\/baw-workers\/tmp\/settings.default.yml","namespace":"settings"/)
      expect(worker_log_content).to include('"redis":{"configured":true,"namespace":"resque","connection":"fake"')
      expect(worker_log_content).to include('"resque_worker":{"running":true,"mode":"bg","pid_file":"./tmp/logs/resque_worker.pid","queues":"example","poll_interval":5}')
      expect(worker_log_content).to include('"logging":{"file_only":true,"worker":1,"mailer":1,"audio_tools":2}')
    end

    it 'runs the setup task for fg worker' do

      reset_settings

      # change settings file to set to foreground.
      original_yaml = YAML.load_file(RSpec.configuration.default_settings_path)
      original_yaml['settings']['resque']['background_pid_file'] = nil
      new_file = File.expand_path(File.join(temporary_dir, 'fg_worker.yml'))
      File.write(new_file, YAML.dump(original_yaml))

      # simulate running a resque worker

      BawWorkers::Config.run(settings_file: new_file, redis: true, resque_worker: true)

      expect(worker_log_content).to match(/"test":true,"file":"#{new_file}","namespace":"settings"/)
      expect(worker_log_content).to include('"redis":{"configured":true,"namespace":"resque","connection":"fake"')
      expect(worker_log_content).to include('"resque_worker":{"running":true,"mode":"fg","pid_file":null,"queues":"example","poll_interval":5}')
      expect(worker_log_content).to include('"logging":{"file_only":true,"worker":1,"mailer":1,"audio_tools":2}')
    end

    it 'runs stop_all task' do
      # simulate running the stop_all rake task
      BawWorkers::ResqueApi.workers_running
      BawWorkers::ResqueApi.workers_stop_all

      expect(worker_log_content).to include('No Resque workers currently running.')
      expect(worker_log_content).to include("Pids of running Resque workers: ''.")
    end

    it 'runs current task' do
      # simulate running the current rake task
      BawWorkers::ResqueApi.workers_running

      expect(worker_log_content).to include('No Resque workers currently running.')
      expect(worker_log_content).to_not include("Pids of running Resque workers: ''.")
    end

  end
end
