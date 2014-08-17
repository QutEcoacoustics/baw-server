shared_context 'rspect_output_files' do
  let(:rspec_stdout_path) { RSpec.configuration.rspec_stdout_path }
  let(:rspec_stdout_content) { File.read(rspec_stdout_path) }

  let(:rspec_stderr_path) { RSpec.configuration.rspec_stderr_path }
  let(:rspec_stderr_content) { File.read(rspec_stderr_path) }

  let(:resque_output_log_file) { RSpec.configuration.resque_stdout_path }
  let(:resque_output_log_content) { File.read(resque_output_log_file) }

  let(:resque_error_log_file) { RSpec.configuration.resque_stderr_path }
  let(:resque_error_log_content) { File.read(resque_error_log_file) }

  let(:default_settings_file) { RSpec.configuration.default_settings_path }
end