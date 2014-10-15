# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'baw-workers/version'

Gem::Specification.new do |spec|
  spec.name          = 'baw-workers'
  spec.version       = BawWorkers::VERSION
  spec.authors       = ['Mark Cottman-Fields']
  spec.email         = ['qut.bioacoustics.research+mark@gmail.com']
  spec.summary       = %q{Bioacoustics Workbench workers}
  spec.description   = %q{Workers that can process various asynchronous long-running or intensive tasks.}
  spec.homepage      = 'https://github.com/QutBioacoustics/baw-workers'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # dev dependencies
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'listen'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'guard-yard'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'codeclimate-test-reporter'
  spec.add_development_dependency 'webmock'
  spec.add_development_dependency 'zonebie'
  spec.add_development_dependency 'i18n'
  spec.add_development_dependency 'tzinfo'
  spec.add_development_dependency 'fakeredis'

  # runtime dependencies
  spec.add_runtime_dependency 'daemons'
  spec.add_runtime_dependency 'resque', '~> 1.25.2'
  spec.add_runtime_dependency 'settingslogic'
  spec.add_runtime_dependency 'activesupport', '>= 3.2'
  spec.add_runtime_dependency 'resque_solo'
  spec.add_runtime_dependency 'resque-status'
  spec.add_runtime_dependency 'actionmailer', '>= 3.2'
end
