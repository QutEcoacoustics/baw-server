=begin
#SFTPGo

#SFTPGo REST API

The version of the OpenAPI document: 2.0.0

Generated by: https://openapi-generator.tech
OpenAPI Generator version: 5.0.0-SNAPSHOT

=end

require 'spec_helper'
require 'json'

# Unit tests for SftpgoGeneratedClient::VersionApi
# Automatically generated by openapi-generator (https://openapi-generator.tech)
# Please update as you see appropriate
describe 'VersionApi' do
  before do
    # run before each test
    @api_instance = SftpgoGeneratedClient::VersionApi.new
  end

  after do
    # run after each test
  end

  describe 'test an instance of VersionApi' do
    it 'should create an instance of VersionApi' do
      expect(@api_instance).to be_instance_of(SftpgoGeneratedClient::VersionApi)
    end
  end

  # unit tests for get_version
  # Get version details
  # @param [Hash] opts the optional parameters
  # @return [VersionInfo]
  describe 'get_version test' do
    it 'should work' do
      # assertion here. ref: https://www.relishapp.com/rspec/rspec-expectations/docs/built-in-matchers
    end
  end

end