RSpec::Core::RakeTask.new('docs:generate:append', :spec_file) do |t, task_args|
  if spec_file = task_args[:spec_file]
    ENV['DOC_FORMAT'] = 'append_json'
  end
  t.pattern    = spec_file || 'spec/acceptance/**/*_spec.rb'
  t.rspec_opts = ['--format RspecApiDocumentation::ApiFormatter']
end