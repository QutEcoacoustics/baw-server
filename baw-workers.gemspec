# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'baw-workers/version'

Gem::Specification.new do |spec|
  spec.name          = 'baw-workers'
  spec.version       = BawWorkers::VERSION
  spec.authors       = ['Mark Cottman-Fields']
  spec.email         = ['cofiem@gmail.com']
  spec.summary       = %q{Bioacoustics Workbench workers}
  spec.description   = %q{Workers that can process various asynchronous long-running or intensive tasks.}
  spec.homepage      = 'https://github.com/QutBioacoustics/baw-workers'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # dev dependencies
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 11.1'
  spec.add_development_dependency 'guard', '~> 2.11'
  spec.add_development_dependency 'guard-rspec', '~> 4.5'
  spec.add_development_dependency 'guard-yard', '~> 2.1'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 0.4'
  spec.add_development_dependency 'webmock', '~> 2.0'
  spec.add_development_dependency 'zonebie', '~> 0.5'
  spec.add_development_dependency 'i18n', '~> 0.7'
  spec.add_development_dependency 'tzinfo', '~> 1.2'
  spec.add_development_dependency 'fakeredis', '~> 0.5'

  # runtime dependencies
  spec.add_runtime_dependency 'resque', '~> 1.25'
  spec.add_runtime_dependency 'settingslogic', '~> 2.0'
  spec.add_runtime_dependency 'activesupport', '>= 4.2'
  spec.add_runtime_dependency 'resque_solo', '~> 0.1'
  spec.add_runtime_dependency 'resque-status', '~> 0.5'
  spec.add_runtime_dependency 'actionmailer', '>= 4.2'
end
