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

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'guard', '~> 1.8'
  spec.add_development_dependency 'listen', '~> 1'
  spec.add_development_dependency 'guard-rspec'
  # for guard on windows
  spec.add_development_dependency 'wdm', '>= 0.1.0' if RbConfig::CONFIG['target_os'] =~ /mswin|mingw|cygwin/i
end
