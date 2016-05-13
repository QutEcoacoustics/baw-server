# More info at https://github.com/guard/guard#readme
notification :off

guard :rspec, cmd: 'bin/rspec --format progress --color' do
  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^lib/(.+)\.rb$}) { |m| ["spec/#{m[1]}_spec.rb", *((0..9).map { |i| "spec/#{m[1]}_#{i}_spec.rb" })] }
  watch('spec/spec_helper.rb') { 'spec' }
  #watch(/(.*)/) { |m| puts "Unknown file: #{m[1]}"; nil }
end

# guard :yard, port: 8808, stdout: './tmp/yard-out.log', stderr: './tmp/yard-err.log' do
#   watch(%r{lib/.+\.rb})
# end
