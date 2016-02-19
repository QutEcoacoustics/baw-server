# More info at https://github.com/guard/guard#readme
notification :off

guard :rspec, cmd: 'bin/rspec --format progress --color' do
  watch(%r{^spec/.+_spec\.rb$})
  watch('spec/spec_helper.rb')                         { 'spec' }

  # Rails specs
  watch(%r{^app/models/(.+)\.rb$})                     { |m| "spec/models/#{m[1]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})   { |m|
    possible_files('spec/controllers/%{name}_%{number}controller_spec.rb', m[1]) +
        possible_files('spec/acceptance/%{name}_%{number}spec.rb', m[1]) +
        ['lib/api_documentation_spec.rb'] }

  watch(%r{^spec/support/(.+)\.rb$})                   { 'spec' }
  watch('config/routes.rb')                            { 'spec/routing' }
  watch('app/controllers/application_controller.rb')   { 'spec/acceptance' }
  watch('app/models/ability.rb')                       { 'spec/acceptance' }
  watch('lib/api_documentation_spec.rb')               { 'spec/acceptance' }

  # Capybara features specs
  watch(%r{^app/views/(.+)/.*\.(erb|haml)$})           { |m| "spec/features/#{m[1]}_spec.rb" }
  watch(%r{^app/controllers/(.+)_(controller)\.rb$})   { |m| "spec/features/#{m[1]}_spec.rb" }
  watch(%r{^app/models/(.+)\.rb$})                     { |m| "spec/features/#{m[1]}s_spec.rb" }
  watch(%r{^app/models/(.+)\.rb$})                     { |m| possible_files('spec/acceptance/%{name}s_%{number}spec.rb', m[1]) }

  # for lib folder
  watch(%r{^lib/modules/(.+)\.rb$})                    { |m| "spec/lib/#{m[1]}_spec.rb" }
  watch('spec/lib/creation.rb')                            { |m| 'spec/lib/creation_spec.rb' }

  # changes to factories
  watch(%r{^spec/factories/(.+)_(factory).rb$})        { |m| [
      "spec/features/#{m[1]}s_spec.rb",
      "spec/features/#{m[1]}_spec.rb",
      "spec/acceptance/#{m[1]}s_spec.rb",
      "spec/acceptance/#{m[1]}_spec.rb",
      "spec/models/#{m[1]}s_spec.rb",
      "spec/models/#{m[1]}_spec.rb",
      'lib/api_documentation_spec.rb']}
end

def possible_files(path_template, name)
  base = path_template % { name:name, number:''}
  numbered = (1..10).map { |i| path_template % { name:name, number:"#{i}_"} }
  [base] + numbered
end

