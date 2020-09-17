=begin
#SFTPGo

#SFTPGo REST API

The version of the OpenAPI document: 2.0.0

Generated by: https://openapi-generator.tech
OpenAPI Generator version: 5.0.0-SNAPSHOT

=end

require 'spec_helper'
require 'json'
require 'date'

# Unit tests for SftpgoGeneratedClient::ApiResponse
# Automatically generated by openapi-generator (https://openapi-generator.tech)
# Please update as you see appropriate
describe 'ApiResponse' do
  before do
    # run before each test
    @instance = SftpgoGeneratedClient::ApiResponse.new
  end

  after do
    # run after each test
  end

  describe 'test an instance of ApiResponse' do
    it 'should create an instance of ApiResponse' do
      expect(@instance).to be_instance_of(SftpgoGeneratedClient::ApiResponse)
    end
  end
  describe 'test attribute "message"' do
    it 'should work' do
      # assertion here. ref: https://www.relishapp.com/rspec/rspec-expectations/docs/built-in-matchers
    end
  end

  describe 'test attribute "error"' do
    it 'should work' do
      # assertion here. ref: https://www.relishapp.com/rspec/rspec-expectations/docs/built-in-matchers
    end
  end

end