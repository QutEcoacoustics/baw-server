shared_context 'rspect_output_files' do

  let(:tmp_dir) { RSpec.configuration.tmp_dir }
  let(:example_media_dir) { File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'example_media')) }

  let(:program_stderr_file) { RSpec.configuration.program_stderr }
  let(:program_stderr_content) { File.read(program_stderr_file) }

  let(:program_stdout_file) { RSpec.configuration.program_stdout }
  let(:program_stdout_content) { File.read(program_stdout_file) }

  let(:default_settings_file) { RSpec.configuration.default_settings_path }
end