# -*- encoding: utf-8 -*-

=begin
#SFTPGo

#SFTPGo REST API

The version of the OpenAPI document: 2.0.0

Generated by: https://openapi-generator.tech
OpenAPI Generator version: 5.0.0-SNAPSHOT

=end

$:.push File.expand_path("../lib", __FILE__)
require "sftpgo_generated_client/version"

Gem::Specification.new do |s|
  s.name        = "sftpgo_generated_client"
  s.version     = SftpgoGeneratedClient::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["OpenAPI-Generator"]
  s.email       = [""]
  s.homepage    = "https://openapi-generator.tech"
  s.summary     = "SFTPGo Ruby Gem"
  s.description = "SFTPGo REST API"
  s.license     = "Unlicense"
  s.required_ruby_version = ">= 1.9"

  s.add_runtime_dependency 'typhoeus', '~> 1.0', '>= 1.0.1'

  s.add_development_dependency 'rspec', '~> 3.6', '>= 3.6.0'

  s.files         = `find *`.split("\n").uniq.sort.select { |f| !f.empty? }
  s.test_files    = `find spec/*`.split("\n")
  s.executables   = []
  s.require_paths = ["lib"]
end