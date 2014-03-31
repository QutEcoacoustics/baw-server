shared_context 'common' do

  let(:config_example) { "#{Dir.pwd}/lib/baw-workers/settings/settings.example.yml" }
  let(:log_file) { "#@tmp_dir/spec.log" }

  before(:each) do
    Settings.source(config_example)
    Settings.namespace('settings')
  end
end