# frozen_string_literal: true

require 'workers_helper'

describe 'rake tasks' do
  require 'helpers/shared_test_helpers'

  include_context 'shared_test_helpers'

  context 'rake task' do
    before(:each) do
      File.delete worker_log_file if File.exist? worker_log_file
    end

    after(:each) do
      # reset settings
      BawWorkers::Config.run({})
    end

    it 'runs the setup task for bg worker' do
      pid_file = File.join(temporary_dir, 'resque_worker.pid')
      File.delete pid_file if File.exist? pid_file

      # change settings file to set to background.
      new_settings = {
        resque: {
          background_pid_file: pid_file
        }
      }
      new_file = File.expand_path(File.join(temporary_dir, 'bg_worker.yml'))
      File.write(new_file, new_settings.deep_stringify_keys.to_yaml)

      # simulate running a resque worker
      BawWorkers::Config.run(settings_file: new_file, redis: true, resque_worker: true)

      expect(worker_log_content).to match(/"test":true,"environment":"test","files":\[.*"#{new_file}".*\]/)
      expect(worker_log_content).to include('"redis":{"namespace":"resque","connection":{"host":"redis","port":6379,"password":null,"db":1}')
      expect(worker_log_content).to include("\"resque_worker\":{\"running\":true,\"mode\":\"bg\",\"pid_file\":\"#{pid_file}\",\"queues\":\"analysis_test,maintenance_test,harvest_test,media_test,mirror_test\",\"poll_interval\":0.5}")
      expect(worker_log_content).to include('"logging":{"worker":1,"mailer":1,"audio_tools":1')

      File.delete pid_file if File.exist? pid_file
    end

    it 'runs the setup task for fg worker' do
      settings_path = File.join(BawApp.root, 'config', 'settings', 'test.yml')
      BawWorkers::Config.run(
        settings_file: settings_path,
        redis: true,
        resque_worker: true
      )

      expect(worker_log_content).to match(%r{"test":true,"environment":"test","files":\[.+/baw-server/config/settings/test.yml"})
      expect(worker_log_content).to include('"redis":{"namespace":"resque","connection":{"host":"redis","port":6379,"password":null,"db":1}')
      expect(worker_log_content).to include('"resque_worker":{"running":true,"mode":"fg","pid_file":null,"queues":"analysis_test,maintenance_test,harvest_test,media_test,mirror_test","poll_interval":0.5}')
      expect(worker_log_content).to include('"logging":{"worker":1,"mailer":1,"audio_tools":1')
    end

    it 'runs stop_all task' do
      BawWorkers::Config.run({})

      # simulate running the stop_all rake task
      BawWorkers::ResqueApi.clear_workers
      BawWorkers::ResqueApi.workers_running
      BawWorkers::ResqueApi.workers_stop_all

      expect(worker_log_content).to include('No Resque workers currently running.')
      expect(worker_log_content).to include("Pids of running Resque workers: ''.")
    end

    it 'runs current task' do
      BawWorkers::Config.run({})

      # simulate running the current rake task
      BawWorkers::ResqueApi.clear_workers
      BawWorkers::ResqueApi.workers_running

      expect(worker_log_content).to include('No Resque workers currently running.')
      expect(worker_log_content).to_not include("Pids of running Resque workers: ''.")
    end
  end
end
