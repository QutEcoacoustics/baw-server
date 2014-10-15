# More info at https://github.com/guard/guard#readme
notification :off

guard :rspec, cmd: 'bundle exec rspec --format progress --color' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$})     { |m| "spec/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { 'spec' }
end

guard :yard, port: 8808, stdout: './tmp/yard-out.log', stderr: './tmp/yard-err.log' do
  watch(%r{lib/.+\.rb})
end
