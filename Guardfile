# More info at https://github.com/guard/guard#readme
notification :off

guard :rspec, cmd: 'bundle exec rspec --format progress --color' do
  watch(%r{^spec/.+_spec\.rb$})

  watch(%r{^lib/(.+)\.rb$})         { |m| "spec/lib/#{m[1]}_spec.rb" }

  watch(%r{^spec/support/.+\.rb$})  { 'spec' }
  watch('spec/spec_helper.rb')      { 'spec' }
end