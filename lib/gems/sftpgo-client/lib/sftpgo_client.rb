# frozen_string_literal: true

require 'faraday'
require 'faraday_middleware'
require 'uri'
require 'dry/monads'
require 'dry/validation'
require 'dry-struct'
require 'dry/logic'
require 'dry/logic/predicates'

# A wrapper module for the sftpgo REST API
module SftpgoClient
  require_relative 'sftpgo_client/api_client'
end
