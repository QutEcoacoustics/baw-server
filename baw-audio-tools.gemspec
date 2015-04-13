# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'baw-audio-tools/version'
require 'rbconfig'

Gem::Specification.new do |spec|
  spec.name          = 'baw-audio-tools'
  spec.version       = BawAudioTools::VERSION
  spec.authors       = ['Mark Cottman-Fields']
  spec.email         = ['qut.bioacoustics.research+mark@gmail.com']
  spec.summary       = %q{Bioacoustics Workbench audio tools}
  spec.description   = %q{Contains the audio, spectrogram, and caching tools for the Bioacoustics Workbench project.}
  spec.homepage      = 'https://github.com/QutBioacoustics/baw-audio-tools'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  # dev dependencies
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'guard', '~> 2.12'
  spec.add_development_dependency 'guard-rspec', '~> 4.5'
  spec.add_development_dependency 'guard-yard', '~> 2.1'
  spec.add_development_dependency 'simplecov', '~> 0.9'
  spec.add_development_dependency 'coveralls', '~> 0.8'
  spec.add_development_dependency 'codeclimate-test-reporter', '~> 0.4'
  spec.add_development_dependency 'zonebie', '~> 0.5'
  spec.add_development_dependency 'i18n', '~> 0.7'
  spec.add_development_dependency 'tzinfo', '~> 1.2'

  # runtime dependencies
  spec.add_runtime_dependency 'activesupport', '>= 3.2'

end
